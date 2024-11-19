

class transaction;

 randc bit [3:0] a;
 randc bit [3:0] b;
 bit [4:0] sum;

 // Function to know the current value of Txn Class
  function void display();
    $display("a : %0d \t b: %0d \t sum: %0d",a,b,sum);
  endfunction

  // We dont want obj to keep history of variables so we declare deep copy method

  function transaction copy();
    copy = new();
    copy.a = this.a;
    copy.b = this.b;
  endfunction

endclass


class driver;
  
  virtual add_if.DRV aif;
  mailbox #(transaction) mbx;
  transaction data;
  event next;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    forever begin
      mbx.get(data);
      @(posedge aif.clk);  
      aif.a <= data.a;
      aif.b <= data.b;
      $display("[DRV] : Interface Trigger");
      data.display();
      ->next;
    end
  endtask
  
  
endclass


class generator;

  event done; // this is to hold the simulation until our process is over
  transaction trans;
  mailbox #(transaction) mbx;
  int i = 0;
  event next;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    trans = new();  // this will create single object with history   
  endfunction

  task run();
    for(int i = 0; i < 10; i++) begin
      assert(trans.randomize()) else $display("RANDOMIZATION FAILED");
      $display("[GEN] : Data Sent to Driver");
      trans.display();
      mbx.put(trans.copy);  // This will allow independent values for each copy
      //#20; // Adding random delay to wait after each txn
      @(next);
    end
   ->done;
  endtask

endclass

interface add_if;
  logic [3:0] a;
  logic [3:0] b;
  logic [4:0] sum;
  logic clk;
  
  modport DRV (input a,b, input sum,clk);
  
endinterface


 
 
 
module tb;
  
  generator gen;
  mailbox #(transaction) mbx;
  event done;


  add_if aif();
  driver drv;
  
  add dut (aif.a, aif.b, aif.sum, aif.clk );
 
  initial begin
    mbx = new();
    drv = new(mbx);
    gen = new(mbx);
    drv.next = gen.next;
    drv.aif = aif;
    done = gen.done;
    
  end

  initial begin
    fork
      gen.run();
      drv.run();
    join_none 
    wait(done.triggered);
    $finish;
  end


  initial begin
    aif.clk <= 0;
  end
  
  always #10 aif.clk <= ~aif.clk;
  
  initial begin
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end
  
endmodule
