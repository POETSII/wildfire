# Wildfire

Wildfire is a hardware compiler for a simple imperative language
extended with **non-deterministic choice**.  For example, here is a
wildfire program that solves the
[N-Queens](https://en.wikipedia.org/wiki/Eight_queens_puzzle) problem:

```ada
-- Number of queens & dimensions of board
const N = 18

-- State of squares on the current row
var safe   : bit(N)   -- Safe squares
var l      : bit(N)   -- Attacked (left diag)
var r      : bit(N)   -- Attacked (right diag)
var c      : bit(N)   -- Attacked (column)
var choice : bit(N)   -- Chosen square

safe := ~0 ;   -- Initially, all squares safe
while safe != 0 do
  -- Isolate the first hot bit in safe
  choice := safe & (~safe + 1) ;
  -- Place a queen here & move to next row
     ( l := (l|choice) << 1
    || r := (r|choice) >> 1
    || c := c|choice
     ; safe := ~(l|r|c) )
  -- Or, do not place a queen here
  ?  ( safe := safe & ~choice )
end ;
-- Fail unless every column has a queen
if c != ~0 then fail end
```

The source language supports sequential composition (`;`), parallel
composition (`||`), loops (`while`), conditionals (`if`),
non-deterministic choice (`?`), and failure (`fail`).

The compiler works by creating many instances of the program (which we
call *processors*) on FPGA, connected according to a topology
specified at compile-time.

To execute a statement *s1 ? s2*, a processor *p* either:

1. Copies its local state to a neighbouring processor and tells it to
execute *s2*.  Meanwhile *p* proceeds by executing *s1*.  In this
case, we say that *p* spawns *s2*.

2. If no neighbouring processor is idle then the local state is
pushed onto *p*'s stack. Processor *p* executes *s1* and then, after
backtracking, *s2*.

There are two properties of the implementation that make this
efficient: (1) determining an idle neighbour is a single-cycle
operation; (2) copying a processor's state to a neighbouring processor
is optimised using wide inter-processor channels.

The language supports arrays as well as register variables.  Arrays
are implemented using on-chip block RAMs.  This means they tend to be
small, and hence quick to copy.  Read-only arrays are implemented as
block RAMs that are shared between any number of processors (the
number can be changed using a compiler option) -- they can be quite a
bit larger than read-write arrays and they don't need to be copied
during spawning.

So far there are three wildfire applications:

  * [N-Queens solver](apps/queens/queens.w)
  * [Golomb ruler solver](apps/golomb/golomb1.w)
  * [SAT solver](apps/sat/sat.w)

For further details and performance results, please see this
[unpublished report](wildfire.pdf).
