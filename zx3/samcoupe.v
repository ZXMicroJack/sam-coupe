`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:39:25 07/25/2015 
// Design Name: 
// Module Name:    tld_sam 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module samcoupezx3 (
    input wire clk50mhz,
    // Audio I/O
    input wire ear,
    output wire audio_left,
    output wire audio_right,
    // Audio I2S
    output wire i2s_bclk,
    output wire i2s_lrclk,
    output wire i2s_dout,
    // Video output
    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hs,
    output wire vga_vs,
    // SRAM interface
    output wire [19:0] sram_addr,
    inout wire [7:0] sram_data,
    output wire sram_we_n,
    output wire sram_oe_n,
    output wire sram_ub_n,
    output wire sram_lb_n,
    // PS/2 keyoard interface
    inout wire clkps2,
    inout wire dataps2,
    // mouse interface
    inout wire mousedata,
    inout wire mouseclk,
    //////// sdcard ////////
    output wire sd_cs_n,
    output wire sd_clk,
    output wire sd_mosi,
    input wire sd_miso,
    output wire led,
    input wire joy_data,
    output wire joy_clk,
    output wire joy_load_n
    );

    // Interface with RAM
    wire [18:0] sram_addr_from_sam;
    wire sram_we_n_from_sam;

    // VGA mapping
    wire[2:0] r;
    wire[2:0] g;
    wire[2:0] b;
    wire hsync, vsync;
    assign vga_r[7:0] = {r[2:0], 5'd0};
    assign vga_g[7:0] = {g[2:0], 5'd0};
    assign vga_b[7:0] = {b[2:0], 5'd0};
    assign vga_hs = hsync;
    assign vga_vs = vsync;
    
    // Audio and video
    wire [1:0] sam_r, sam_g, sam_b;
    wire sam_bright;
    
	 // scandoubler
	 wire hsync_pal, vsync_pal;
    wire [2:0] ri = {sam_r, sam_bright};
    wire [2:0] gi = {sam_g, sam_bright};
    wire [2:0] bi = {sam_b, sam_bright};

  //ctrl-module
  wire[7:0] disk_data_in0;
  wire[7:0] disk_data_out0;
  wire[31:0] disk_sr;
  wire[31:0] disk_cr;
  wire disk_data_clkout, disk_data_clkin;

    wire clk24, clk12, clk6, clk8, clk48;

    wire scanlines_tg;
    wire scandbl_tg;
                       
    relojes los_relojes (
        .CLK_IN1            (clk50mhz),      // IN
        // Clock out ports
        .CLK_OUT1           (clk24),  // modulo multiplexor de SRAM
        .CLK_OUT2           (clk12),  // ASIC
        .CLK_OUT3           (clk6),   // CPU y teclado PS/2
        .CLK_OUT4           (clk8),   // SAA1099 y DAC
        .CLK_OUT5           (clk48)  // un reloj duplicado de 50Mhz
    );

    wire joy1up, joy1down, joy1left, joy1right, joy1fire1, joy1fire2, joy1fire3;
    wire joy2up, joy2down, joy2left, joy2right, joy2fire1, joy2fire2, joy2fire3;
    wire[5:0] joystick1 = {joy1left, joy1right, joy1down, joy1up, (joy1fire1&joy1fire2&joy1fire3)};
    wire[5:0] joystick2 = {(joy2fire1&joy2fire2&joy2fire3), joy2up, joy2down, joy2right, joy2left};

    wire[8:0] audio_out_left;
    wire[8:0] audio_out_right;
    wire[7:0] sram_data_from_chip;
    wire[7:0] sram_data_to_chip;
    wire pwon_reset;
    wire REBOOT;
    samcoupe maquina (
        .clk48(clk48),
        .clk24(clk24),
        .clk12(clk12),
        .clk6(clk6),
        .clk8(clk8),
        .master_reset_n(~pwon_reset),
        // Video output
        .r(sam_r),
        .g(sam_g),
        .b(sam_b),
        .bright(sam_bright),
        .hsync_pal(hsync_pal),
        .vsync_pal(vsync_pal),
        // Audio output
        .ear(ear),
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right),
        // PS/2 keyboard
        .clkps2(host_divert_keyboard ? 1'b1 : clkps2),
        .dataps2(host_divert_keyboard ? 1'b1 : dataps2),
        // PS/2 mouse
        .mousedata(mousedata),
        .mouseclk(mouseclk),
        // SRAM external interface
        .sram_addr(sram_addr_from_sam),
        .sram_data_from_chip(sram_data_from_chip),
        .sram_data_to_chip(sram_data_to_chip),
        .sram_we_n(sram_we_n_from_sam),
        .disk_data_in(disk_data_in0),
        .disk_data_out(disk_data_out0),
        .disk_sr(disk_sr),
        .disk_cr(disk_cr),
        .disk_data_clkout(disk_data_clkout),
        .disk_data_clkin(disk_data_clkin),
        .disk_wp(dswitch[7:6]),
        .scanlines_tg(scanlines_tg),
        .scandbl_tg(scandbl_tg),
        .joysplitter_tg(),
        .joystick1(joystick1),
        .joystick2(joystick2),
        .REBOOT(REBOOT)
  );
  
  reg scanlines_inv = 1'b0;
  reg scandbl_inv = 1'b0;
  always @(posedge scanlines_tg)
    scanlines_inv <= ! scanlines_inv;
  always @(posedge scandbl_tg)
    scandbl_inv <= ! scandbl_inv;
	 
	wire[7:0] vga_red_o, vga_green_o, vga_blue_o;
  wire config_vga_on;
  wire config_scanlines_off;
	vga_scandoubler #(.CLKVIDEO(12000)) salida_vga (
		.clkvideo(clk12),
		.clkvga(clk24),
		.enable_scandoubling(config_vga_on ^ scandbl_inv),
    .disable_scaneffect(config_scanlines_off ^ scanlines_inv),
		.ri(vga_red_o[7:5]),
		.gi(vga_green_o[7:5]),
		.bi(vga_blue_o[7:5]),
		.hsync_ext_n(hsync_pal),
		.vsync_ext_n(vsync_pal),
		.ro(r),
		.go(g),
		.bo(b),
		.hsync(hsync),
		.vsync(vsync)
   );


   wire host_divert_keyboard;
   wire[15:0] dswitch;
   wire host_divert_sdcard;

  wire osd_window;
  wire osd_pixel;
  
   assign led = sd_cs_n ? 1'b0 : 1'b1;
    
   CtrlModule MyCtrlModule (
     .clk(clk6),
     .clk26(clk48),
     .reset_n(1'b1),

     //-- Video signals for OSD
     .vga_hsync(hsync_pal),
     .vga_vsync(vsync_pal),
     .osd_window(osd_window),
     .osd_pixel(osd_pixel),

     //-- PS2 keyboard
     .ps2k_clk_in(clkps2),
     .ps2k_dat_in(dataps2),

     //-- SD card signals
     .spi_clk(sd_clk),
     .spi_mosi(sd_mosi),
     .spi_miso(sd_miso),
     .spi_cs(sd_cs_n),

     //-- DIP switches
     .dipswitches(dswitch),

     //-- Control signals
     .host_divert_keyboard(host_divert_keyboard),
     .host_divert_sdcard(host_divert_sdcard),

     // disk interface
     .disk_data_in(disk_data_out0),
     .disk_data_out(disk_data_in0),
     .disk_data_clkin(disk_data_clkout),
     .disk_data_clkout(disk_data_clkin),

      // disk interface
      .disk_sr(disk_sr),
      .disk_cr(disk_cr)
   );

   wire[3:0] vga_r_o;
   wire[3:0] vga_g_o;
   wire[3:0] vga_b_o;

   wire[7:0] vga_red_i, vga_green_i, vga_blue_i;

   assign vga_red_i = {ri[2:0], 5'h0};
   assign vga_green_i = {gi[2:0], 5'h0};
   assign vga_blue_i = {bi[2:0], 5'h0};
   
   // OSD Overlay
   OSD_Overlay overlay (
     .clk(clk48),
     .red_in(vga_red_i),
     .green_in(vga_green_i),
     .blue_in(vga_blue_i),
     .window_in(1'b1),
     .osd_window_in(osd_window),
     .osd_pixel_in(osd_pixel),
     .hsync_in(hsync_pal),
     .red_out(vga_red_o),
     .green_out(vga_green_o),
     .blue_out(vga_blue_o),
     .window_out( ),
     .scanline_ena(1'b0)
   );

   // TODO audio_out_left / right
  i2s_sound #(.CLKMHZ(24)) i2scodec (
    .clk(clk24),
    .audio_l({audio_out_left[8:0], 7'd0}),
    .audio_r({audio_out_right[8:0], 7'd0}),
    .i2s_bclk(i2s_bclk),
    .i2s_lrclk(i2s_lrclk),
    .i2s_dout(i2s_dout)
  );
  
  // TODO audio_out_left / right
  sigma_delta_codec sdcodec (
    .clk(clk24),
    .audio_l({audio_out_left[8:0], 7'd0}),
    .audio_r({audio_out_right[8:0], 7'd0}),
    .sd_audio_l(audio_left),
    .sd_audio_r(audio_right)
  );

  return_to_core1 reset_total (
    .clk(clk24),
    .boot_core(REBOOT)
  );
  
  joydecoder decodificador_joysticks (
    .clk(clk24),
    .joy_data(joy_data),
    .joy_latch_megadrive(1'b1),
    .joy_clk(joy_clk),
    .joy_load_n(joy_load_n),
    .joy1up(joy1up),
    .joy1down(joy1down),
    .joy1left(joy1left),
    .joy1right(joy1right),
    .joy1fire1(joy1fire1),
    .joy1fire2(joy1fire2),
    .joy1fire3(joy1fire3),
    .joy1start(),
    .joy2up(joy2up),
    .joy2down(joy2down),
    .joy2left(joy2left),
    .joy2right(joy2right),
    .joy2fire1(joy2fire1),
    .joy2fire2(joy2fire2),
    .joy2fire3(joy2fire3),
    .joy2start()
  );
  
  config_retriever modo_video_inicial (
    .clk(clk24),
    .sram_addr_in(sram_addr_from_sam),
    .sram_we_n_in(sram_we_n_from_sam),
    .sram_oe_n_in(~sram_we_n_from_sam),
    .sram_data_from_chip(sram_data_from_chip),
    .sram_data_to_chip(sram_data_to_chip),
    .sram_addr_out(sram_addr),
    .sram_we_n_out(sram_we_n),
    .sram_oe_n_out(sram_oe_n),
    .sram_ub_n_out(sram_ub_n),
    .sram_lb_n_out(sram_lb_n),
    .sram_data(sram_data),
    .pwon_reset(pwon_reset),
    .vga_on(config_vga_on),
    .scanlines_off(config_scanlines_off)
  );

   
endmodule
