# Zig Projects

### RSA Suite (Zig 13.0)

Here's an example output:
```
Generating primes:
Primes p and q: 691 641
Proving they are prime:
  a  |  b  |  q  |  r  |  s  |  t
691 | 641 | 1 | 50 | 1 | -1
641 | 50 | 12 | 41 | -12 | 13
50 | 41 | 1 | 9 | 13 | -14
41 | 9 | 4 | 5 | -64 | 69
9 | 5 | 1 | 4 | 77 | -83
5 | 4 | 1 | 1 | -141 | 152
4 | 1 | 4 | 0 | 641 | -691
gcd is 1
bezier coeffs are s=-141, t=152: -141*691+152*641=1
```
Our prime number generator uses Euler primes from the sequence $k^2-k+41$ when $0 < k < 41$.
```
Found the public key exponent
e, n = 1231      442931
```
We generate a random public key coefficient `e` that's smaller than `n` but is still sufficiently large. `n` is simply a product of `q` and `p`.
```
Finding the private key exponent through inverse mod with egcd
  a  |  b  |  q  |  r  |  s  |  t
441600 | 1231 | 358 | 902 | 1 | -358
1231 | 902 | 1 | 329 | -1 | 359
902 | 329 | 2 | 244 | 3 | -1076
329 | 244 | 1 | 85 | -4 | 1435
244 | 85 | 2 | 74 | 11 | -3946
85 | 74 | 1 | 11 | -15 | 5381
74 | 11 | 6 | 8 | 101 | -36232
11 | 8 | 1 | 3 | -116 | 41613
8 | 3 | 2 | 2 | 333 | -119458
3 | 2 | 1 | 1 | -449 | 161071
2 | 1 | 2 | 0 | 1231 | -441600
gcd is 1
bezier coeffs are s=-449, t=161071: -449*441600+161071*1231=1
```
We generate the private key `d` by calculating the inverse modulos of `e` such that $e*d \equiv 1 (mod\: \phi(n))$. In our case, `d` is the positive beizer coefficient.

```
Found the full keypair:
e = 1231
d = 161071
n = 442931
Proving d * e === 1 (mod totient)
161071 * 1231 = 441600 * 449 + 1
```

### Linked Lists (Zig 13.0)

A Python list in Zig with the same methods and properties.

Example output:
```
Print my list:
3  133  44  44  44  42
Print my list BACKWARDS:
42  44  44  44  133  3

Inline reversing my list...
Print reversed list:
42  44  44  44  133  3
Print reversed list BACKWARDS (so should be normal):
3  133  44  44  44  42

Popping the last element...
This is my popped node: LinkedList.Node{ .value = 3, .next = null, .prev = null }
And the list looks like this now:
42  44  44  44  133
133  44  44  44  42

Let's get rid of 133
42  44  44  44
44  44  44  42

Let's get rid of 100 (it doesn't exist)
I errored!!
42  44  44  44
44  44  44  42

How many 44's are there?
There are 3 44's.

Let's remove all the 44's
42
42
Yey Linked Lists :)
```

### LC3 Virtual Machine (Zig 14.0)

Sources:
[Writing your Own Virtual Machine](https://www.jmeiners.com/lc3-vm/)
[lc3vm-zig](https://github.com/mdaverde/lc3vm-zig/blob/main/src/main.zig)
[lets build an lc 3 virtual machine](https://www.rodrigoaraujo.me/posts/lets-build-an-lc-3-virtual-machine/)


> Note: Raw mode on terminal doesn't work properly, you have to press [ENTER] to input a character.

There are a bunch of programs in `/images`. The proper one to run are the `.obj` files.

If you don't want the detailed instructions run like this:
```
zig run -lc src/main.zig -- images/programs/rogue.obj release
```
Otherwise run without `release`.

Example of `character_counter.obj`:
```
zig run -lc lc3-zig/src/main.zig -- lc3-zig/images/programs/character_counter/character_counter.obj release
Starting the VM...
Character Counter - Copyleft (c) Dennis Ideler.
Please enter a line of lower case text.
asdfasdfqwertyuiopasdfasdf
asdfasdfqwertyuiopasdfasdf
a:4
b:0
c:0
d:4
e:1
f:4
g:0
h:0
i:1
j:0
k:0
l:0
m:0
n:0
o:1
p:1
q:1
r:1
s:4
t:1
u:1
v:0
w:1
x:0
y:1
z:0
HALT
```

Example with debug prints on `hello2.obj`:
```
zig run -lc lc3-zig/src/main.zig -- lc3-zig/images/hello2.obj
File start: 3000
Filename: /home/wslappendix/.cache/zig/o/88a2d62dfdda1e6f7ede7cb12b4a097b/main lc3-zig/images/hello2.obj
Starting the VM...
Breakdown of instruction: 1110000000000101 hardware.vm.Instruction.OP_LEA
Registers in 0x: { 3007, 0, 0, 0, 0, 0, 0, 0, 3002, 1 }
Breakdown of instruction: 0010001000010011 hardware.vm.Instruction.OP_LD
Registers in 0x: { 3007, 5, 0, 0, 0, 0, 0, 0, 3003, 1 }
Breakdown of instruction: 1111000000100010 hardware.vm.Instruction.OP_TRAP
Hello, World!
Registers in 0x: { 3007, 5, 0, 0, 0, 0, 0, 3004, 3004, 1 }
Breakdown of instruction: 0001001001111111 hardware.vm.Instruction.OP_ADD
Registers in 0x: { 3007, 4, 0, 0, 0, 0, 0, 3004, 3005, 1 }
Breakdown of instruction: 0000001111111101 hardware.vm.Instruction.OP_BR
Registers in 0x: { 3007, 4, 0, 0, 0, 0, 0, 3004, 3003, 1 }
Breakdown of instruction: 1111000000100010 hardware.vm.Instruction.OP_TRAP
Hello, World!
Registers in 0x: { 3007, 4, 0, 0, 0, 0, 0, 3004, 3004, 1 }
Breakdown of instruction: 0001001001111111 hardware.vm.Instruction.OP_ADD
Registers in 0x: { 3007, 3, 0, 0, 0, 0, 0, 3004, 3005, 1 }
Breakdown of instruction: 0000001111111101 hardware.vm.Instruction.OP_BR
Registers in 0x: { 3007, 3, 0, 0, 0, 0, 0, 3004, 3003, 1 }
Breakdown of instruction: 1111000000100010 hardware.vm.Instruction.OP_TRAP
Hello, World!
Registers in 0x: { 3007, 3, 0, 0, 0, 0, 0, 3004, 3004, 1 }
Breakdown of instruction: 0001001001111111 hardware.vm.Instruction.OP_ADD
Registers in 0x: { 3007, 2, 0, 0, 0, 0, 0, 3004, 3005, 1 }
Breakdown of instruction: 0000001111111101 hardware.vm.Instruction.OP_BR
Registers in 0x: { 3007, 2, 0, 0, 0, 0, 0, 3004, 3003, 1 }
Breakdown of instruction: 1111000000100010 hardware.vm.Instruction.OP_TRAP
Hello, World!
Registers in 0x: { 3007, 2, 0, 0, 0, 0, 0, 3004, 3004, 1 }
Breakdown of instruction: 0001001001111111 hardware.vm.Instruction.OP_ADD
Registers in 0x: { 3007, 1, 0, 0, 0, 0, 0, 3004, 3005, 1 }
Breakdown of instruction: 0000001111111101 hardware.vm.Instruction.OP_BR
Registers in 0x: { 3007, 1, 0, 0, 0, 0, 0, 3004, 3003, 1 }
Breakdown of instruction: 1111000000100010 hardware.vm.Instruction.OP_TRAP
Hello, World!
Registers in 0x: { 3007, 1, 0, 0, 0, 0, 0, 3004, 3004, 1 }
Breakdown of instruction: 0001001001111111 hardware.vm.Instruction.OP_ADD
Registers in 0x: { 3007, 0, 0, 0, 0, 0, 0, 3004, 3005, 2 }
Breakdown of instruction: 0000001111111101 hardware.vm.Instruction.OP_BR
Registers in 0x: { 3007, 0, 0, 0, 0, 0, 0, 3004, 3006, 2 }
Breakdown of instruction: 1111000000100101 hardware.vm.Instruction.OP_TRAP
HALT
```