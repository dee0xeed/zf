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

## Links

* [Starting FORTH](https://www.forth.com/starting-forth/)
* [Forth standart](https://forth-standard.org/standard/core)
* [Open FirmWare/Forth Lessons](https://wiki.laptop.org/go/Forth_Lessons)
* [Implementing a FORTH virtual machine](http://www.w3group.de/forth_course.html)
