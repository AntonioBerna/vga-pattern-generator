interface axis_video_if;
  logic [23:0] tdata;
  logic        tvalid;
  logic        tready;
  logic        tlast;
  logic        tuser;

  modport source(output tdata, output tvalid, output tlast, output tuser, input tready);

  modport sink(input tdata, input tvalid, input tlast, input tuser, output tready);
endinterface
