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

```zig
vm.code[0] = vm.dict.getWordNumber("prom").?;
vm.code[1] = vm.dict.getWordNumber("read").?;
vm.code[2] = vm.dict.getWordNumber("jifz").?;
vm.code[3] = 7;
vm.code[4] = vm.dict.getWordNumber("exec").?;
vm.code[5] = vm.dict.getWordNumber("jump").?;
vm.code[6] = 0;
vm.code[7] = vm.dict.getWordNumber("bye").?;
```

```
zf> .code
code[0] = 0xffffffffffffff01 // print 'zf> ' ('zf(c)> ' when "compiling") <--|
code[1] = 0xffffffffffffff02 // read a word                                  |
code[2] = 0xffffffffffffff05 // if TOS == 0, jump to                         |
code[3] = 0x0000000000000007 // this location           -->|                 |
code[4] = 0xffffffffffffff03 // execute the word           |                 |
code[5] = 0xffffffffffffff04 // unconditional jump to the  |                 |
code[6] = 0x0000000000000000 // beginning                  |              -->|
code[7] = 0xffffffffffffff0b // bye                     <--|
```

## try it

### sqr

```
zf> : raise-to-the-power-of-two
zf(c)> dup * .
zf(c)> ;
zf> : τετραγωνίζω
zf(c)> dup * .
zf(c)> ;
zf> : в-квадрате
zf(c)> dup * .
zf(c)> ;
zf>
zf> 5 raise-to-the-power-of-two cr
25
zf> 8 τετραγωνίζω cr
64 
zf> 9 в-квадрате cr
81
```

### loop

```
zf> : foreach 
zf(c)> iter i . next 
zf(c)> ;
zf> 
zf> 5 1 foreach cr
1 2 3 4 
zf>
```

NOTE: `iter` and `next` are just synonyms for standart words `do` and `loop`, respectively.

## Links

* [Starting FORTH](https://www.forth.com/starting-forth/)
* [Forth standart](https://forth-standard.org/standard/core)
* [Open FirmWare/Forth Lessons](https://wiki.laptop.org/go/Forth_Lessons)
* [Implementing a FORTH virtual machine](http://www.w3group.de/forth_course.html)
