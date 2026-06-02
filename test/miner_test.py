import os
import re
import subprocess
import time
import select
import sys
import unittest
import random

# Suppress stack trace printing when a test fails
sys.tracebacklimit = 0

VALID_SOF = 0xAA
DISALLOWED_SRCS = (0xF0, 0xF1)
VALID_DSTS = (0x01, 0x02, 0x03)
VALID_TYPES = (0x01, 0x02, 0x03)
DEADBEEF = (0xDE, 0xAD, 0xBE, 0xEF)

def build_packet(sof, src, dst, typ, length, payload, chk=None):
    """Python implementation to build packet. Checksum will be computed as (SRC + DST + TYPE + LEN + payload) mod 256 if there is no chk value (which is expected). However, if there is a chk value it will be used as part of the packet inspection process."""
    
    checksum_fields = [src, dst, typ, length] + list(payload)
    if chk is None:
        chk = sum(checksum_fields) % 256
    return [sof] + checksum_fields + [chk]

def packet_to_hex_str(packet):
    """Formats the packet in hex with bytes separated by spaces."""

    return " ".join(f"{b:02X}" for b in packet)

class TestInspector(unittest.TestCase):
    score = 0
    max_score = 0

    @classmethod
    def tearDownClass(cls):
        print(f"\n======================================\nFINAL SCORE: {cls.score} / {cls.max_score}\n======================================")

    def _interact_with_sim(self, cmd, cwd, input_str):
        """Run the simulation."""
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            cwd=cwd,
            text=False
        )
        
        try:
            start_time = time.time()
            timeout = 600 # 10 minutes
            output_data = ""
            prompt_found = False
            
            while True:
                if time.time() - start_time > timeout:
                    self.fail("Simulation timed out.")
                    
                # Wait for output data to become available
                ready, _, _ = select.select([proc.stdout], [], [], 1.0)
                if ready:
                    try:
                        chunk = os.read(proc.stdout.fileno(), 4096).decode('utf-8', errors='replace')
                    except OSError:
                        break
                        
                    if not chunk:
                        break # Reached EOF
                        
                    output_data += chunk
                    
                    # Wait for the input prompt before sending data
                    if not prompt_found and "Enter command:" in output_data:
                        prompt_found = True
                        proc.stdin.write(input_str.encode('utf-8'))
                        proc.stdin.flush()
                        
                    # Stop reading upon completion and terminate gracefully
                    if prompt_found and "Processing complete!" in output_data:
                        break
        finally:
            proc.terminate()
            proc.wait()
            if proc.stdin:
                proc.stdin.close()
            if proc.stdout:
                proc.stdout.close()
            
        return output_data

    def send_packet(self, packet):
        """Helper method to run the make sim simulation, send a packet, and parse the outputs."""
        project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        
        # Format inputs space-separated (scanf expects hex strings without 0x prefix for %x)
        input_str = f"{packet_to_hex_str(packet)}\n"
        
        output_data = self._interact_with_sim(['make', 'sim'], project_root, input_str)
        
        evaluation_match = re.search(r'(Accept|Drop|Invalid|Timeout|Error)\s*\n', output_data)
        cycles_match = re.search(r'Cycles:\s+(\d+)', output_data)
        
        if not evaluation_match:
            self.fail(f"Failed to parse evaluation for simulation output.'\nPacket Sent: {packet_to_hex_str(packet)}\nSimulation output: {output_data}\n")
            
        return {
            'evaluation': evaluation_match.group(1) if evaluation_match else None,
            'cycles': int(cycles_match.group(1)) if cycles_match else None,
            'raw_stdout': output_data
        }

    def evaluate_packet(self, packet, expected, description):
        """Send a packet, share the evaluation and if it matches the expected evaluation or not."""
        res = self.send_packet(packet)
        if res['evaluation']  != expected:
            self.fail(f"\n[FAILED] {description}\n"
            f"Packet: {packet_to_hex_str(packet)}\n"
            f"Evaluation: {res['evaluation']}\n"
            f"Expected Evaluation: {expected}\n"
            f"Cycles: {res['cycles']}\n"
            f"Error: Returned Evaluation does not match Expected Evaluation\n"
            f"Simulator output: \n{res['raw_stdout'][-1000:]}"
            )
 
        print(f"[PASSED] {description} | Packet: {packet_to_hex_str(packet)} | Evaluation: {res['evaluation']} | Cycles: {res['cycles']}")
                
    def test_00_compilation(self):
        """Test that the application compiles successfully."""
        print("\n--- Testing Compilation ---")
        op_score = 0
        total_points = 10
        TestInspector.max_score += total_points
        try:
            project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
            
            # Clean any previous builds
            subprocess.run(['make', 'clean'], cwd=project_root, capture_output=True)
            
            # Run the compilation target 
            result = subprocess.run(
                ['make', 'compile'],
                cwd=project_root,
                capture_output=True,
                text=True
            )
            
            # Verify the command succeeded
            self.assertEqual(result.returncode, 0, f"\n[FAILED] Compilation failed:\n{result.stderr}\n{result.stdout}")
            
            TestInspector.score += total_points
            op_score += total_points
            print(f"[OPERATION PASSED] Compilation - Scored {op_score}/{total_points} points.")
        except AssertionError as e:
            print(f"[OPERATION FAILED] Compilation - Scored {op_score}/{total_points} points.")
            raise e

    def test_01_invalid_packet(self):
        """Test invalid packets to see if they will be evaluated as invalid."""
        print(f"\n--- Testing invalid packet evaluation ---")
        op_score = 0
        total_points = 30 # 3 tests * 10 points
        TestInspector.max_score += total_points

        try:
            #sof, src, dst, type, len, payload)
            self.evaluate_packet(build_packet(0xBB, 0x01, 0x01, 0x02, 0x00, []), 'Invalid', "Illegal start of frame 0xBB. Expected sof 0xAA.")
            op_score += 10
            TestInspector.score += 10

            self.evaluate_packet(build_packet(VALID_SOF, 0x02, 0x02, 0x04, 0x00, []), 'Invalid', "Illegal type 0x04. Expected 01, 02, or 03.")
            op_score += 10
            TestInspector.score += 10

            self.evaluate_packet(build_packet(VALID_SOF, 0x03, 0x03, 0x01, 0x09, [0]*9), 'Invalid', "Out of range length (0x09). Expected 0x08 or less.")
            op_score += 10
            TestInspector.score += 10
            print(f"[OPERATION PASSED] invalid packets evaluated as invalid - Scored {op_score}/{total_points} points.")
        except AssertionError as e:
            print(f"[OPERATION FAILED] Invalid packets not evaluated as invalid - Scored {op_score}/{total_points} points.")
            raise e

    def test_02_invalid_checksum(self):
        """Packets with wrong checksums will be evaluated as invalid."""
        print(f"\n--- Testing invalid packet evaluation ---")
        op_score = 0
        total_points = 10 # 1 tests * 10 points
        TestInspector.max_score += total_points

        try:
            #sof, src, dst, type, len, payload)
            packet = build_packet(VALID_SOF, 0x01, 0x01, 0x03, 0x02, [0xAA, 0xBB], chk = 0x00)
            self.evaluate_packet(packet, 'Invalid', "Wrong checksum (0x00). Expected 0x6C.")
            op_score += 10
            TestInspector.score += 10

            print(f"[OPERATION PASSED] Packets with wrong checksums evalauted as invalid - Scored {op_score}/{total_points} points.")
        except AssertionError as e:
            print(f"[OPERATION FAILED] Packets with wrong checksums not evaluated as invalid - Scored {op_score}/{total_points} points.")
            raise e

    def test_03_drop_packet(self):
        """Test suspicious packets to see if they will be dropped."""
        print(f"\n--- Testing threatening packet evaluation ---")
        op_score = 0
        total_points = 40 # 4 tests * 10 points
        TestInspector.max_score += total_points

        try:
            #sof, src, dst, type, len, payload)
            self.evaluate_packet(build_packet(VALID_SOF, 0xF0, 0x01, 0x02, 0x00, []), 'Drop', "Disallowed source (0xF0).")
            op_score += 10
            TestInspector.score += 10
            self.evaluate_packet(build_packet(VALID_SOF, 0xF1, 0x01, 0x02, 0x00, []), 'Drop', "Disallowed source (0xF1).")
            op_score += 10
            TestInspector.score += 10

            self.evaluate_packet(build_packet(VALID_SOF, 0x02, 0x04, 0x02, 0x06, [0]*6), 'Drop', "Illegal destination. Expected 0x01, 0x02, or 0x03.")
            op_score += 10
            TestInspector.score += 10

            self.evaluate_packet(build_packet(VALID_SOF, 0xCC, 0x02, 0x01, 0x04, list(DEADBEEF)), 'Drop', "Suspicious DEADBEEF payload byte sequence.")
            op_score += 10
            TestInspector.score += 10

            print(f"[OPERATION PASSED] Potentially malicious packets dropped - Scored {op_score}/{total_points} points.")
        except AssertionError as e:
            print(f"[OPERATION FAILED] Potentially malicious packets not dropped - Scored {op_score}/{total_points} points.")
            raise e

    def test_04_valid_packet(self):
        """Test the acceptance of valid packets."""
        print(f"\n--- Testing valid packet acceptance ---")
        op_score = 0
        total_points = 30 # 3 tests * 10 points
        TestInspector.max_score += total_points
        
        # Increasing order of difficulty (Payload gets bigger)
        try:
            cases = [ #description, sof, src, dst, type, len, payload)
                ("No payload", VALID_SOF, 0x01, 0x01, 0x02, 0x00, []),
                ("3-byte payload", VALID_SOF, 0x08, 0x02, 0x01, 0x03, [0x11, 0x22, 0x33]),
                ("Maximum payload", VALID_SOF, 0x10, 0x03, 0x03, 0x08, [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x01]),
            ]
            for desc, sof, src, dst, typ, length, payload in cases:
                packet = build_packet(sof, src, dst, typ, length, payload)
                self.evaluate_packet(packet, 'Accept', desc)
                op_score += 10
                TestInspector.score += 10
            print(f"[OPERATION PASSED] Valid packets accepted - Scored {op_score}/{total_points} points.")
        except AssertionError as e:
            print(f"[OPERATION FAILED] Valid packets not accepted - Scored {op_score}/{total_points} points.")
            raise e            








if __name__ == '__main__':
    unittest.main()
