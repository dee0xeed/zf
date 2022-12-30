# zf
An implementation of FORTH-like virtual stack machine in Zig

## words

```
zf> .dict
bye . cr .dict .dstk .rstk .text .data dup drop + 1+ - 1- * / mod = <> > < 0= 0<> 0> 0<
max min ! @ allot create : ; if else then do iter i loop next begin again until (
```

## shell

```zig
vm.code[0] = vm.dict.getWordNumber("prom").?;
vm.code[1] = vm.dict.getWordNumber("read").?;
vm.code[2] = vm.dict.getWordNumber("jifz").?;
vm.code[3] = 7;
vm.code[4] = vm.dict.getWordNumber("proc").?;
vm.code[5] = vm.dict.getWordNumber("jump").?;
vm.code[6] = 0;
vm.code[7] = vm.dict.getWordNumber("bye").?;
```

```
zf> .text
code[0] = 0xffffffffffffff01 // print 'zf> ' ('zf(c)> ' when "compiling") <--|
code[1] = 0xffffffffffffff02 // read a word                                  |
code[2] = 0xffffffffffffff05 // if TOS == 0, jump to                         |
code[3] = 0x0000000000000007 // this location           -->|                 |
code[4] = 0xffffffffffffff03 // process the word           |                 |
code[5] = 0xffffffffffffff04 // unconditional jump         |                 |
code[6] = 0x0000000000000000 // to the beginning           |              -->|
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

NOTE: `iter` and `next` are just synonyms for standard words `do` and `loop`, respectively.

### variables

```
zf> 3 allot
zf> .data
data[0] = 0x0000000000000000
data[1] = 0x0000000000000000
data[2] = 0x0000000000000000
zf> -3 allot
zf> .data
zf> create var1 1 allot
zf> create var2 1 allot
zf> .data
data[0] = 0x0000000000000000
data[1] = 0x0000000000000000
zf> 7 var1 !
zf> 8 var2 !
zf> .data
data[0] = 0x0000000000000007
data[1] = 0x0000000000000008
zf> var1 @ var2 @ * . cr
56 
```

```
zf> : var create 1 allot ;
zf> : km 1000 * ;
zf> : hour 3600 * ;
zf> var distance
zf> var time
zf> var speed
zf> 100 km distance !
zf> 1 hour time !
zf> distance @ time @ / speed !
zf> .data
data[0] = 0x00000000000186a0 ('distance')
data[1] = 0x0000000000000e10 ('time')
data[2] = 0x000000000000001b ('speed')
zf> : take-and-print @ . cr ;
zf> speed take-and-print
27 \ in m/s

```

### using non-interactively

```
$ cat lib.zf app.zf | zig-out/bin/zf 
zf> zf> zf> zf> 
7 
zf> 
Bye, see you later!

```

```
$ cat lib.zf 
: var create 1 allot ;
: ? @ . cr ;

$ cat app.zf 
var x
7 x !
cr x ?
```

## Links

* [Starting FORTH](https://www.forth.com/starting-forth/)
* [Forth standard](https://forth-standard.org/standard/core)
* [Open FirmWare/Forth Lessons](https://wiki.laptop.org/go/Forth_Lessons)
* [Implementing a FORTH virtual machine](http://www.w3group.de/forth_course.html)
* [MuP21 instruction set](https://groups.google.com/g/comp.lang.forth/c/7UULcFs7kas)
* [do-loop](https://stackoverflow.com/questions/6949434/how-to-implement-loop-in-a-forth-like-language-interpreter-written-in-c)
* [do-leave-loop](https://stackoverflow.com/questions/58304029/how-is-forth-leave-loop-implemented-since-number-of-leaves-is-not-known-bef)
* [create-does](//https://softwareengineering.stackexchange.com/questions/339283/forth-how-do-create-and-does-work-exactly)
* [Multiple 'DOES>'](http://forum.6502.org/viewtopic.php?f=9&t=5118&view=next)
* [immediate -> ndcs](http://www.euroforth.org/ef17/papers/pelc.pdf)

## ...

```
zf> .text
text[0000] = 0000000000000001 `prom`
text[0001] = 0000000000000002 `read`
text[0002] = 0000000000000005 `jifz`
text[0003] = 0000000000000007 (to 7)
text[0004] = 0000000000000003 `proc`
text[0005] = 0000000000000004 `jump`
text[0006] = 0000000000000000 (to 0)
text[0007] = 000000000000000b `bye`
```
now add some word

```
: odd? 1 and 0<> if 1 else 0 then . cr ;
```

```
zf> .text
...
text[0008] = 0000000000000007 `lit`
text[0009] = 0000000000000001 (1)
text[000a] = 0000000000000016 `and`
text[000b] = 0000000000000026 `0<>`
text[000c] = 0000000000000005 `jifz`
text[000d] = 0000000000000012 (to 12)
text[000e] = 0000000000000007 `lit`
text[000f] = 0000000000000001 (1)
text[0010] = 0000000000000004 `jump`
text[0011] = 0000000000000014 (to 14)
text[0012] = 0000000000000007 `lit`
text[0013] = 0000000000000000 (0)
text[0014] = 000000000000000c `.`
text[0015] = 000000000000000d `cr`
text[0016] = 0000000000000006 `return`
```

## ... `does>`

```
zf> : self-incrementing-var create 1 allot does> dup @ 1+ swap ! ;
zf> 
zf> self-incrementing-var i1
zf> self-incrementing-var i2
zf> .data
...
data[2] = 0x0000000000000000 ('i1')
data[3] = 0x0000000000000000 ('i2')
zf> i1 i1 i1 i1 i1 i1 
zf> i2
zf> .data
...
data[2] = 0x0000000000000006 ('i1')
data[3] = 0x0000000000000001 ('i2')
```

## ... `array`

### source

```
: array ( n -- )
    create dup , allot
    does>
        over 1 < if
            drop drop
        else
            2dup @ > if
                drop drop
            else
                over + swap drop
            then
        then
;
```

### code

```
text[0078] = 0000000000000027 'create'
text[0079] = 0000000000000006 'dup'
text[007a] = 0000000000000048 ','
text[007b] = 0000000000000026 'allot'
text[007c] = 0000000000000029 'does'
text[007d] = 0000000000000003 'ret'
text[007e] = 000000000000003d 'over'
text[007f] = 0000000000000005 'lit'
text[0080] = 0000000000000001 (1)
text[0081] = 0000000000000017 '<'
text[0082] = 0000000000000002 'jifz'
text[0083] = 0000000000000088 (-->88)
text[0084] = 0000000000000007 'drop'
text[0085] = 0000000000000007 'drop'
text[0086] = 0000000000000001 'jump'
text[0087] = 0000000000000095 (-->95)
text[0088] = 000000000000003f '2dup'
text[0089] = 0000000000000019 '@'
text[008a] = 0000000000000016 '>'
text[008b] = 0000000000000002 'jifz'
text[008c] = 0000000000000091 (-->91)
text[008d] = 0000000000000007 'drop'
text[008e] = 0000000000000007 'drop'
text[008f] = 0000000000000001 'jump'
text[0090] = 0000000000000095 (-->95)
text[0091] = 000000000000003d 'over'
text[0092] = 000000000000000f '+'
text[0093] = 0000000000000008 'swap'
text[0094] = 0000000000000007 'drop'
text[0095] = 0000000000000003 'ret'
```

### test

```
zf> 3 array a
zf> 3 array b
zf> 
zf> 7 1 b ! 
zf> 8 2 b !
zf> 9 3 b !
zf> .data
data[0] = 0x0000000000000003 ('a')
data[1] = 0x0000000000000000 ('-')
data[2] = 0x0000000000000000 ('-')
data[3] = 0x0000000000000000 ('-')
data[4] = 0x0000000000000003 ('b')
data[5] = 0x0000000000000007 ('-')
data[6] = 0x0000000000000008 ('-')
data[7] = 0x0000000000000009 ('-')
```

## ... `tick`, `exec`

```
zf> 5 ' . exec cr
5 
```

## ... `postpone`

```
: endif postpone then ; immediate
: if-so-then postpone if ; immediate
```

```
zf> : not-zero? if-so-then 111 . cr else 222 . cr endif ;
zf> 5 not-zero?
111 
zf> 0 not-zero?
222 
zf> -5 not-zero?
111 
```
