#include <iostream>
#include <memory>
#include "Vneorv32_verilog_tb.h"
#include "verilated.h"
#include <unistd.h>
#include <fcntl.h>

// UART timing configuration
#define CLK_FREQ 100000000
#define BAUD_RATE 19200
#define CYCLES_PER_BIT (CLK_FREQ / BAUD_RATE)

int main(int argc, char** argv) {
    // Setup Verilator context
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->commandArgs(argc, argv);
    
    // Instantiate the compiled Verilog model
    const std::unique_ptr<Vneorv32_verilog_tb> top{new Vneorv32_verilog_tb{contextp.get()}};

    // Make STDIN non-blocking so read() doesn't stall the simulation
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

    // Initial inputs
    top->clk = 0;
    top->nrst = 0;
    top->uart_rxd = 1;

    int tx_state = 0;
    int tx_baud_counter = 0;
    int tx_bit_counter = 0;
    char tx_char = 0;

    int rx_state = 0;
    int rx_baud_counter = 0;
    int rx_bit_counter = 0;
    int rx_poll_counter = 0;
    char rx_char = 0;

    // Simulation loop
    while (!contextp->gotFinish()) {
        // Toggle Clock
        top->clk = !top->clk;
        
        // Release Reset after 100 simulated cycles
        if (contextp->time() > 100) {
            top->nrst = 1;
        }

        // Evaluate the processor hardware state
        top->eval();

        // Evaluate UART I/O on the rising clock edge
        if (top->clk) {
            // TX: NEORV32 -> STDOUT
            if (tx_state == 0 && top->uart_txd == 0) { // Start Bit
                tx_state = 1;
                tx_baud_counter = CYCLES_PER_BIT / 2; // Offset by half a bit to sample in the middle
            } else if (tx_state > 0) {
                if (--tx_baud_counter <= 0) {
                    tx_baud_counter = CYCLES_PER_BIT;
                    if (tx_state == 1) { // Start bit complete
                        tx_state = 2; tx_bit_counter = 0; tx_char = 0;
                    } else if (tx_state == 2) { // Data bits
                        tx_char |= (top->uart_txd << tx_bit_counter++);
                        if (tx_bit_counter == 8) tx_state = 3;
                    } else if (tx_state == 3) { // Stop bit
                        std::cout << tx_char << std::flush;
                        tx_state = 0;
                    }
                }
            }

            // RX: STDIN -> NEORV32
            if (rx_state == 0) {
                // Poll for new characters periodically to avoid syscall overhead on every cycle
                if (++rx_poll_counter >= 1000) {
                    rx_poll_counter = 0;
                    if (read(STDIN_FILENO, &rx_char, 1) == 1) {
                        rx_state = 1; // Start Bit
                        rx_baud_counter = CYCLES_PER_BIT;
                        top->uart_rxd = 0;
                    }
                }
            } else if (rx_state > 0) {
                if (--rx_baud_counter <= 0) {
                    rx_baud_counter = CYCLES_PER_BIT;
                    if (rx_state == 1) { // Start bit complete
                        rx_state = 2; rx_bit_counter = 0;
                        top->uart_rxd = rx_char & 1;
                    } else if (rx_state == 2) { // Data bits
                        rx_bit_counter++;
                        if (rx_bit_counter < 8) {
                            top->uart_rxd = (rx_char >> rx_bit_counter) & 1;
                        } else { // Stop bit
                            rx_state = 3;
                            top->uart_rxd = 1;
                        }
                    } else if (rx_state == 3) { // Stop bit complete
                        rx_state = 0;
                    }
                }
            }
        }

        contextp->timeInc(1);
    }
    return 0;
}