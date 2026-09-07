//default clocking Clk @(posedge clk);
//endclocking

logic f_past_valid;
initial f_past_valid=0;
always @(posedge clk)
	f_past_valid <= 1'b1;


always @(posedge clk)
    if(!f_past_valid)
	assume(aresetn==0);

// assume property (   @(posedge clk)  (~clk) == $past(clk));
logic   [1:0] idx, head;

//assume_sym_idx: assume property ( @(posedge clk) disable iff(!aresetn)  ##1 $stable(idx)  );
 assume_sym_idx: assume property ( @(posedge clk) disable iff(!aresetn)  f_past_valid  |-> idx==$past(idx)  );

//assume_input: assume property( @(posedge clk) disable iff(!aresetn) (i_req[idx] && !o_grant[idx] ) |=> i_req[idx]   );

assume_input: assume property (@(posedge clk) disable iff (!aresetn)   f_past_valid &&   $past(i_req[idx] && !o_grant[idx] )   |->  i_req[idx]);

assume_invariant :assume property (@(posedge clk) disable iff (!aresetn)
		  (head == 2'b00 && mask_rg == 4'b1111) ||
 		  (head == 2'b01 && mask_rg == 4'b1110) ||
 		  (head == 2'b10 && mask_rg == 4'b1100) ||
 	 	  (head == 2'b11 && mask_rg == 4'b1000));

//genvar j;
//generate 
//for(j=0 ;j<4;j++) begin :gen
//asssume_in: assume property( @(posedge clk) disable iff(!aresetn) (i_req[j] && !o_grant[j] ) |=> i_req[j]   );
//end 
//endgenerate

///// round robin head priority based on prev gnt /////////////////////

always @(posedge clk,negedge aresetn ) begin
   if(!aresetn) 
    head <= 2'b00;
  else  begin 
    if(o_grant[0])  head <= 2'b01;
    if(o_grant[1])  head <= 2'b10;
    if(o_grant[2])  head <= 2'b11;
    if(o_grant[3])  head <= 2'b00;
  end 
end 

assert_head_grant : assert property ( @(posedge clk) disable iff(!aresetn)  head == idx && i_req[idx] |->  o_grant[idx]  );

assert_inv_grant_req : assert property ( @(posedge clk) disable iff(!aresetn)    o_grant[idx] && head == idx  |->   i_req[idx]  );

assert_head_grant_low : assert property ( @(posedge clk) disable iff(!aresetn)  (head == idx && (!i_req[idx]) )  |->  (!o_grant[idx] ) );
 
assert_head_next_grant : assert property ( @(posedge clk) disable iff(!aresetn)  (  head == idx && (!i_req[idx]  && i_req[idx+1'b1] ) )  |->  (!o_grant[idx] && o_grant[idx+1'b1] ) );

cover_head_next_grant : cover property ( @(posedge clk) disable iff(!aresetn)  ( head == idx && (!i_req[idx]  && i_req[idx+1'b1] ) )  &&  ( !o_grant[idx] && o_grant[idx+1'b1] ) );

//cover_req_changed : cover property(  @(posedge clk)  ##1$changed(  i_req )  );

cover_all_req : cover property ( @(posedge clk) disable iff(!aresetn)  ( &i_req == 1 ));
cover_no_req : cover property ( @(posedge clk) disable iff(!aresetn)  ( |i_req == 0 ));

cover_grant0 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[0] ));
cover_grant1 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[1] ));
cover_grant2 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[2] ));
cover_grant3 : cover property ( @(posedge clk) disable iff(!aresetn)  (  i_req[3] ));

assert_onehot0_grant: assert property (@(posedge clk) disable iff(!aresetn)  ( $countones(o_grant) == 1)  || ($countones(o_grant) == 0) );// onehot0
 
cover_onehot_grant: cover property(@(posedge clk) disable iff(!aresetn)   ( (|o_grant == 1) && (o_grant & (o_grant-1'b1)) == 0   )     );  // onehot

cover_no_grant:  cover property(@(posedge clk) disable iff(!aresetn)   $countones(o_grant) == 0); 

//genvar i;
//generate 
//for(i=0 ;i<4;i++) begin :gen
//ass3: assert property( @(posedge clk) disable iff(!aresetn) (i_req[i] && !o_grant[i] ) |=> i_req[i]   );
//end 
//endgenerate

assert_req_dont_retreat: assert property( @(posedge clk) disable iff(!aresetn)  f_past_valid && $past(i_req[idx] && !o_grant[idx] ) |-> i_req[idx]   );


