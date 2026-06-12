#include <stdint.h>
#include <neorv32.h>

// ==============================================================================
// Hardware Register Macros
// ==============================================================================
#define INSPECTOR_BASE   0xF0000000U
#define INSPECTOR_DATA  (*((volatile uint32_t*)(INSPECTOR_BASE + 0x00)))
#define INSPECTOR_EVALUATION  (*((volatile uint32_t*)(INSPECTOR_BASE + 0x04)))
#define INSPECTOR_DONE  (*((volatile uint32_t*)(INSPECTOR_BASE + 0x08)))
#define INSPECTOR_INVALID_COUNT  (*((volatile uint32_t*)(INSPECTOR_BASE + 0x0C)))
#define INSPECTOR_DROP_COUNT (*((volatile uint32_t*)(INSPECTOR_BASE + 0x10)))
#define INSPECTOR_ACCEPT_COUNT   (*((volatile uint32_t*)(INSPECTOR_BASE + 0x14)))
#define INSPECTOR_CLEAR  (*((volatile uint32_t*)(INSPECTOR_BASE + 0x18)))
#define EVALUATION_INVALID 0x1
#define EVALUATION_DROP 0x2
#define EVALUATION_ACCEPT 0x4 


// ==============================================================================
// Helper Functions for Parsing (avoids sscanf footprint)
// ==============================================================================
static const char* parse_word(const char* str, char* word, int max_len) {
    int count = 0;
    while (*str == ' ' || *str == '\t' || *str == '\n' || *str == '\r') str++;
    while (*str && *str != ' ' && *str != '\t' && *str != '\n' && *str != '\r') {
        if (max_len > 0 && count < max_len - 1) {
            *word++ = *str;
            count++;
        }
        str++;
    }
    if (max_len > 0) {
        *word = '\0';
    }
    return str;
}

static const char* parse_hex_byte(const char* str, uint8_t* byte, int* success) {
    *success = 0;
    while (*str == ' ' || *str == '\t' || *str == '\n' || *str == '\r') str++;
    if (!*str) return str;


    uint8_t val = 0;
    int digits = 0;
    while (*str && digits <2) {
        char c = *str;
        if (c >= '0' && c <= '9') {
            val = (val << 4) | (c - '0');
        } else if (c >= 'a' && c <= 'f') {
            val = (val << 4) | (c - 'a' + 10);
        } else if (c >= 'A' && c <= 'F') {
            val = (val << 4) | (c - 'A' + 10);
        } else {
            break;
        }
        str++;
	digits++;
    }
    if (digits > 0) {
	*byte = val;
	*success = 1;
    }
    return str;
}

static int custom_strcmp(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

static void push_byte(uint8_t b) {
    INSPECTOR_DATA = (uint32_t)b;
}

static uint32_t wait_on_evaluation(void) {
    for (uint32_t i = 0; i < 10000; i++) {
        if (INSPECTOR_DONE & 0x1) {
            return INSPECTOR_EVALUATION;
        }
    }
    return (uint32_t)0xFFFFFFFF;
}

static void print_evaluation(uint32_t evaluation) {
    if (evaluation ==(uint32_t)0xFFFFFFFF) {
	neorv32_uart0_printf("Timeout \n");
    } else if (evaluation & EVALUATION_INVALID) {
        neorv32_uart0_printf("Invalid \n");
    } else if (evaluation & EVALUATION_DROP) {
        neorv32_uart0_printf("Drop \n");    
    } else if (evaluation & EVALUATION_ACCEPT) {
        neorv32_uart0_printf("Accept \n");
    } else {
        neorv32_uart0_printf("Error \n");

    }
}

static void cmd_help(void) {
    neorv32_uart0_printf("Packet Inspector commands: \n");
    neorv32_uart0_printf("send 	  -    send a packet formatted similarly to AA 01 02 03 02 11 22 3B \n");
    neorv32_uart0_printf("stats     -    show how many accepted, dropped and invalid packets were encountered \n");
    neorv32_uart0_printf("clear     -    reset counters \n");
    neorv32_uart0_printf("help      -    show inspector commands \n");
    neorv32_uart0_printf("Packet format: SOF SRC DST TYPE LEN PAYLOAD CHK \n");
    neorv32_uart0_printf("valid SOF == 0xAA\n LEN must be 8 bytes or less\n CHK is sum mod 256 \n");
}

static void cmd_send (const char* args) {
    uint32_t start_cycles, end_cycles;
    uint8_t byte;
    uint8_t packet[16];
    int success;
    int byte_count = 0;
    const char* ptr = args;
    while (byte_count < (int)sizeof(packet)){
	ptr = parse_hex_byte(ptr, &byte, &success);
	if (!success) break;
	packet[byte_count++] = byte;
    }

    if (byte_count == 0) {
        neorv32_uart0_printf("No bytes parsed. Expected format: AA 01 02 03 02 11 22 3B \n");
        return;
    }
    neorv32_uart0_printf("Input Packet: \n");
    if (byte_count >= 1) {
	neorv32_uart0_printf("SOF: 0x%x\n", packet[0]);
    } 
    if (byte_count >= 2) {
        neorv32_uart0_printf("SRC: 0x%x\n", packet[1]);
    }    
    if (byte_count >= 3) {
        neorv32_uart0_printf("DST: 0x%x\n", packet[2]);
    }    
    if (byte_count >= 4) {
        neorv32_uart0_printf("TYPE: 0x%x\n", packet[3]);
    }    
    if (byte_count >= 5) {
        neorv32_uart0_printf("LEN: 0x%x\n", packet[4]);
    }    
    if (byte_count >= 7) {
        neorv32_uart0_printf("PAYLOAD:");
	for (int i = 5; i < byte_count - 1; i++) {
            neorv32_uart0_printf("0x%x\n", packet[i]);
    }
    }
    if (byte_count >= 6) {
        neorv32_uart0_printf("CHK: 0x%x\n", packet[byte_count -1]);
    }

    __asm__ volatile ("csrr %0, mcycle" : "=r"(start_cycles));
    for (int i = 0; i < byte_count; i++) {
	push_byte(packet[i]);
    }

    uint32_t evaluation = wait_on_evaluation();
    __asm__ volatile ("csrr %0, mcycle" : "=r"(end_cycles));

    print_evaluation(evaluation);
    neorv32_uart0_printf("Cycles: %u \n", end_cycles - start_cycles);
}

static void cmd_stats(void) {
    uint32_t invalid = INSPECTOR_INVALID_COUNT;
    uint32_t drop = INSPECTOR_DROP_COUNT;
    uint32_t accept = INSPECTOR_ACCEPT_COUNT;
    uint32_t total = invalid + drop + accept;
    neorv32_uart0_printf("Packet Inspector Stats: \n");
    neorv32_uart0_printf("Invalid: %u \n", invalid);
    neorv32_uart0_printf("Dropped: %u \n", drop);
    neorv32_uart0_printf("Accept: %u \n", accept);
    neorv32_uart0_printf("Total: %u \n", total);
    neorv32_uart0_printf("Threat Summary: %u packets failed inspection \n", invalid+ drop);
    }

static void cmd_clear(void) {
    INSPECTOR_CLEAR = 1;
    neorv32_uart0_printf("Counters reset \n");
    } 

int main(void) {
    // Initialize the NEORV32 run-time environment
    neorv32_rte_setup();
    
    // Setup UART0 for printing and scanning (19200 baud is standard for NEORV32)
    neorv32_uart0_setup(19200, 0);

    char cmd[16];
    char input_buf[256];

    neorv32_uart0_printf("*\n*\n*\n*\n*\n*\n*\n*\n");
    cmd_help();

    while (1) {
        neorv32_uart0_printf("Enter command (send/stats/clear/help). If send, include packet bytes in hex separated by spaces (e.g. - send AA 01 02 03 02 11 22 3B):\n");
        
        // Read input line from UART0
        int i = 0;
        while (i < sizeof(input_buf) - 1) {
            char c = neorv32_uart0_getc();
	    neorv32_uart0_putc(c);
            if (c == '\n' || c == '\r') {
	        neorv32_uart0_putc('\n');
                break;
            }
            input_buf[i++] = c;
        }
        input_buf[i] = '\0';

        const char* ptr = parse_word(input_buf, cmd, sizeof(cmd));

        if (cmd[0] == '\0') {
	    continue;
        } else if (custom_strcmp(cmd, "send") == 0) {
            cmd_send(ptr);
	} else if (custom_strcmp(cmd, "stats") == 0) {
            cmd_stats();
        } else if (custom_strcmp(cmd, "clear") == 0) {
            cmd_clear();
        } else if (custom_strcmp(cmd, "help") == 0) {
            cmd_help();
	} else {
            neorv32_uart0_printf("Invalid command. Type help to see command options.\n");
        }

        neorv32_uart0_printf("Processing complete!\n\n");
    }

    return 0;
}
