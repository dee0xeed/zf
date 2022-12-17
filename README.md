# zf
An implementation of FORTH-like virtual stack machine in Zig

## words

```
zf> .dict
bye . cr .dict .dstk .rstk .cstk .code
dup drop
+ 1+ - 1- * / mod = <> > < 0= 0<> 0> 0< max min
: ;
if else then do iter i loop next begin again until (
```

## shell

```
zf> .code
code[0] = 0xffffffffffffff01 // print 'zf>' (zf(c)> when 'compiling')
code[1] = 0xffffffffffffff02 // read a word
code[2] = 0xffffffffffffff05 // if TOS == 0, jump to
code[3] = 0x0000000000000007 // this instruction
code[4] = 0xffffffffffffff03 // execute the word
code[5] = 0xffffffffffffff04 // unconditional jump to the
code[6] = 0x0000000000000000 // beginning
code[7] = 0xffffffffffffff0b // bye
```

## Links

* [Starting FORTH](https://www.forth.com/starting-forth/)
* [Forth standart](https://forth-standard.org/standard/core)
* [Open FirmWare/Forth Lessons](https://wiki.laptop.org/go/Forth_Lessons)
* [Implementing a FORTH virtual machine](http://www.w3group.de/forth_course.html)
