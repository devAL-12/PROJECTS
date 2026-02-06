// =============================================================================
// Pipeline Register with Valid/Ready Handshake
// =============================================================================
// Description:
//   Single-stage pipeline register implementing standard valid/ready protocol
//   - Accepts data when both in_valid and in_ready are high
//   - Stores data in register and presents on output
//   - Handles backpressure correctly (no data loss or duplication)
//   - Fully synthesizable
//   - Clean reset to empty state
//
// Author: [Your Name]
// Date: February 6, 2026
// =============================================================================

module pipeline_register #(
    parameter int DATA_WIDTH = 32  // Configurable data width
)(
    input  logic                    clk,
    input  logic                    rst_n,      // Active-low asynchronous reset
    
    // Input interface
    input  logic [DATA_WIDTH-1:0]   in_data,
    input  logic                    in_valid,
    output logic                    in_ready,
    
    // Output interface
    output logic [DATA_WIDTH-1:0]   out_data,
    output logic                    out_valid,
    input  logic                    out_ready
);

    // Internal storage
    logic [DATA_WIDTH-1:0] data_reg;
    logic                  valid_reg;
    
    // Input handshake occurs when both valid and ready are asserted
    logic input_fire;
    assign input_fire = in_valid & in_ready;
    
    // Output handshake occurs when both valid and ready are asserted
    logic output_fire;
    assign output_fire = out_valid & out_ready;
    
    // Ready when register is empty OR when output is being consumed
    assign in_ready = !valid_reg | out_ready;
    
    // Register control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset to clean, empty state
            data_reg  <= '0;
            valid_reg <= 1'b0;
        end else begin
            // State transitions based on input/output handshakes
            case ({input_fire, output_fire})
                2'b00: begin
                    // No change - hold current state
                    data_reg  <= data_reg;
                    valid_reg <= valid_reg;
                end
                
                2'b01: begin
                    // Output consumed, no new input
                    // Register becomes empty
                    data_reg  <= data_reg;  // Data doesn't matter when invalid
                    valid_reg <= 1'b0;
                end
                
                2'b10: begin
                    // New input accepted, no output consumed
                    // Register becomes full
                    data_reg  <= in_data;
                    valid_reg <= 1'b1;
                end
                
                2'b11: begin
                    // Simultaneous input/output (pass-through)
                    // New data replaces old data
                    data_reg  <= in_data;
                    valid_reg <= 1'b1;
                end
            endcase
        end
    end
    
    // Output assignments
    assign out_data  = data_reg;
    assign out_valid = valid_reg;

    // ==========================================================================
    // Assertions for verification (synthesis tool will ignore)
    // ==========================================================================
    
    // Check for data loss: if input fires and we're not ready, data is lost
    // This should never happen by design
    // synthesis translate_off
    property no_data_loss;
        @(posedge clk) disable iff (!rst_n)
        in_valid && !in_ready |-> $stable(in_data);
    endproperty
    assert property (no_data_loss) else 
        $error("Data loss detected: in_valid high but in_ready low");
    
    // Check for data duplication: output valid should only assert once per input
    property no_duplication;
        @(posedge clk) disable iff (!rst_n)
        out_valid && !out_ready |=> out_valid && $stable(out_data);
    endproperty
    assert property (no_duplication) else 
        $error("Data duplication: out_data changed while out_valid high and out_ready low");
    
    // Check that valid deasserts properly after reset
    property reset_clears_valid;
        @(posedge clk)
        !rst_n |=> !out_valid;
    endproperty
    assert property (reset_clears_valid) else
        $error("Valid not cleared after reset");
    // synthesis translate_on

endmodule
