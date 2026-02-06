// =============================================================================
// Pipeline Register Testbench
// =============================================================================
// Description:
//   Comprehensive testbench for pipeline register with valid/ready handshake
//   Tests:
//     - Basic operation
//     - Backpressure handling
//     - No data loss
//     - No data duplication
//     - Reset behavior
//     - Corner cases
//
// Author: [Your Name]
// Date: February 6, 2026
// =============================================================================

`timescale 1ns/1ps

module pipeline_register_tb;

    // Parameters
    parameter int DATA_WIDTH = 32;
    parameter int CLK_PERIOD = 10;  // 100 MHz
    
    // DUT signals
    logic                    clk;
    logic                    rst_n;
    logic [DATA_WIDTH-1:0]   in_data;
    logic                    in_valid;
    logic                    in_ready;
    logic [DATA_WIDTH-1:0]   out_data;
    logic                    out_valid;
    logic                    out_ready;
    
    // Test control
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
    // Data tracking
    logic [DATA_WIDTH-1:0] sent_data[$];
    logic [DATA_WIDTH-1:0] received_data[$];
    
    // Instantiate DUT
    pipeline_register #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(in_data),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_data(out_data),
        .out_valid(out_valid),
        .out_ready(out_ready)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Monitor input handshakes
    always @(posedge clk) begin
        if (rst_n && in_valid && in_ready) begin
            sent_data.push_back(in_data);
            $display("[%0t] Input accepted: 0x%08h", $time, in_data);
        end
    end
    
    // Monitor output handshakes
    always @(posedge clk) begin
        if (rst_n && out_valid && out_ready) begin
            received_data.push_back(out_data);
            $display("[%0t] Output consumed: 0x%08h", $time, out_data);
        end
    end
    
    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        in_data = '0;
        in_valid = 0;
        out_ready = 0;
        
        $display("========================================");
        $display("PIPELINE REGISTER TESTBENCH");
        $display("Data Width: %0d bits", DATA_WIDTH);
        $display("========================================\n");
        
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        //======================================================================
        // TEST 1: Basic Single Transfer
        //======================================================================
        test_count++;
        $display("\n--- TEST 1: Basic Single Transfer ---");
        
        @(posedge clk);
        in_data = 32'hDEADBEEF;
        in_valid = 1;
        out_ready = 1;
        
        @(posedge clk);
        in_valid = 0;
        
        repeat(3) @(posedge clk);
        
        if (sent_data.size() == 1 && received_data.size() == 1 && 
            sent_data[0] == received_data[0]) begin
            $display("✓ PASS: Data transferred correctly");
            pass_count++;
        end else begin
            $display("✗ FAIL: Data mismatch");
            fail_count++;
        end
        
        sent_data.delete();
        received_data.delete();
        
        //======================================================================
        // TEST 2: Backpressure - Output Not Ready
        //======================================================================
        test_count++;
        $display("\n--- TEST 2: Backpressure Handling ---");
        
        @(posedge clk);
        in_data = 32'hCAFEBABE;
        in_valid = 1;
        out_ready = 0;  // Output not ready
        
        @(posedge clk);
        if (!in_ready) begin
            $display("✓ Backpressure: in_ready correctly deasserted");
        end
        
        // Try to send another word (should not be accepted)
        in_data = 32'h12345678;
        
        repeat(3) @(posedge clk);
        
        // Now make output ready
        out_ready = 1;
        
        @(posedge clk);
        in_valid = 0;
        
        repeat(2) @(posedge clk);
        
        if (received_data.size() == 1 && received_data[0] == 32'hCAFEBABE) begin
            $display("✓ PASS: Backpressure handled correctly, no data loss");
            pass_count++;
        end else begin
            $display("✗ FAIL: Data corrupted under backpressure");
            fail_count++;
        end
        
        sent_data.delete();
        received_data.delete();
        
        //======================================================================
        // TEST 3: Continuous Transfer (No Stalls)
        //======================================================================
        test_count++;
        $display("\n--- TEST 3: Continuous Transfer ---");
        
        out_ready = 1;
        
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            in_data = i;
            in_valid = 1;
        end
        
        @(posedge clk);
        in_valid = 0;
        
        repeat(5) @(posedge clk);
        
        if (sent_data.size() == 10 && received_data.size() == 10) begin
            int mismatch = 0;
            for (int i = 0; i < 10; i++) begin
                if (sent_data[i] != received_data[i]) mismatch = 1;
            end
            
            if (!mismatch) begin
                $display("✓ PASS: All 10 transfers completed correctly");
                pass_count++;
            end else begin
                $display("✗ FAIL: Data mismatch in continuous transfer");
                fail_count++;
            end
        end else begin
            $display("✗ FAIL: Transfer count mismatch (sent=%0d, recv=%0d)", 
                     sent_data.size(), received_data.size());
            fail_count++;
        end
        
        sent_data.delete();
        received_data.delete();
        
        //======================================================================
        // TEST 4: Random Valid/Ready
        //======================================================================
        test_count++;
        $display("\n--- TEST 4: Random Valid/Ready Patterns ---");
        
        fork
            // Input side - random valid
            begin
                for (int i = 0; i < 20; i++) begin
                    @(posedge clk);
                    in_valid = $urandom_range(0, 1);
                    in_data = $urandom();
                end
                @(posedge clk);
                in_valid = 0;
            end
            
            // Output side - random ready
            begin
                for (int i = 0; i < 25; i++) begin
                    @(posedge clk);
                    out_ready = $urandom_range(0, 1);
                end
                out_ready = 1;
            end
        join
        
        // Drain any remaining data
        repeat(10) @(posedge clk);
        
        if (sent_data.size() == received_data.size()) begin
            int mismatch = 0;
            for (int i = 0; i < sent_data.size(); i++) begin
                if (sent_data[i] != received_data[i]) begin
                    mismatch = 1;
                    $display("  Mismatch at index %0d: sent=0x%08h, recv=0x%08h", 
                             i, sent_data[i], received_data[i]);
                end
            end
            
            if (!mismatch) begin
                $display("✓ PASS: Random pattern - all data matched (%0d transfers)", 
                         sent_data.size());
                pass_count++;
            end else begin
                $display("✗ FAIL: Data mismatch in random pattern");
                fail_count++;
            end
        end else begin
            $display("✗ FAIL: Transfer count mismatch (sent=%0d, recv=%0d)", 
                     sent_data.size(), received_data.size());
            fail_count++;
        end
        
        sent_data.delete();
        received_data.delete();
        
        //======================================================================
        // TEST 5: Reset During Operation
        //======================================================================
        test_count++;
        $display("\n--- TEST 5: Reset Behavior ---");
        
        @(posedge clk);
        in_data = 32'hABCDEF00;
        in_valid = 1;
        out_ready = 0;  // Backpressure
        
        @(posedge clk);
        in_valid = 0;
        
        // Now reset
        @(posedge clk);
        rst_n = 0;
        
        repeat(3) @(posedge clk);
        rst_n = 1;
        
        @(posedge clk);
        
        if (!out_valid) begin
            $display("✓ PASS: Reset cleared valid flag");
            pass_count++;
        end else begin
            $display("✗ FAIL: Valid flag not cleared after reset");
            fail_count++;
        end
        
        sent_data.delete();
        received_data.delete();
        
        //======================================================================
        // TEST 6: Back-to-back Transfers with Intermittent Backpressure
        //======================================================================
        test_count++;
        $display("\n--- TEST 6: Intermittent Backpressure ---");
        
        fork
            // Input: continuous stream
            begin
                for (int i = 100; i < 110; i++) begin
                    @(posedge clk);
                    in_data = i;
                    in_valid = 1;
                end
                @(posedge clk);
                in_valid = 0;
            end
            
            // Output: alternating ready/not-ready
            begin
                for (int i = 0; i < 15; i++) begin
                    @(posedge clk);
                    out_ready = i[0];  // Alternating pattern
                end
                out_ready = 1;
            end
        join
        
        repeat(10) @(posedge clk);
        
        if (sent_data.size() == 10 && received_data.size() == 10) begin
            int mismatch = 0;
            for (int i = 0; i < 10; i++) begin
                if (sent_data[i] != received_data[i]) mismatch = 1;
            end
            
            if (!mismatch) begin
                $display("✓ PASS: All data transferred correctly with backpressure");
                pass_count++;
            end else begin
                $display("✗ FAIL: Data corrupted with intermittent backpressure");
                fail_count++;
            end
        end else begin
            $display("✗ FAIL: Transfer count error (sent=%0d, recv=%0d)", 
                     sent_data.size(), received_data.size());
            fail_count++;
        end
        
        //======================================================================
        // Summary
        //======================================================================
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("Pass Rate:   %0d%%", (pass_count * 100) / test_count);
        $display("========================================");
        
        if (fail_count == 0) begin
            $display("✓ ALL TESTS PASSED");
        end else begin
            $display("✗ SOME TESTS FAILED");
        end
        
        $display("\n");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\n✗ ERROR: Testbench timeout!");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("pipeline_register.vcd");
        $dumpvars(0, pipeline_register_tb);
    end

endmodule
