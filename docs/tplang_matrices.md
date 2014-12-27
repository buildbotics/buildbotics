TPLang Matrices
===============

The basic functions of TPLang generate tool paths in the form of GCode.  In
particular the functions ```rapid()``` and ```cut()``` emit rapid and cutting
moves respectively.  For example, the following program generates a movement
about a 1x1 square:

```javascript
rapid(0, 0);
rapid(1, 0);
rapid(1, 1);
rapid(0, 1);
rapid(0, 0);
```

This will produce the following GCode

```
G21    (mm mode)
G0 X1
G0 Y1
G0 X0
G0 Y0
%      (end of program)
```
[Figure 1](figures/figure1.png)

Note, that a starting position of (0, 0) is assumed and GCode only requires
writing the axes which have changed.

The most basic matrix functions are ```translate()```, ```rotate()``` and
```scale()```.  These functions can be used to apply transformations to the
tool paths output by functions like ```rapid()``` and ```cut()```.  For example,
if we take our previous program but first make a call to ```translate()```
the output is effected as follows:

```javascript
translate(1, 1);

rapid(0, 0);
rapid(1, 0);
rapid(1, 1);
rapid(0, 1);
rapid(0, 0);
```

```
G21
G0 X1 Y1
G0 X2
G0 Y2
G0 X1
G0 Y1
%
```
[Figure 3](figures/figure2.png)


Now our 1x1 square has been translated to (1, 1).  We can also scale and rotate
as follows:

```javascript
scale(3, 3);
rotate(Math.PI / 4);
translate(1, 1);

rapid(0, 0);
rapid(1, 0);
rapid(1, 1);
rapid(0, 1);
rapid(0, 0);
```

This produces a 3x3 square rotated 45 degrees and translated to (1, 1).

```
G21
G0 X1 Y1
G0 X3.12132 Y3.12132
G0 X1 Y5.242641
G0 X-1.12132 Y3.12132
G0 X1 Y1
%
```
[Figure 3](figures/figure3.png)

Matrix operations accumulate via matrix multiplication.  The default matrix is
the identity matrix which does not change the tool path output at all.  To get
back to the identity matrix we can call ```loadIdentity()``.  With this ability
we can create square function and apply different matrix transformations to it.
Of course it's not very interesting to do just rapid moves so let's try some
cutting moves connected by a rapid.

```javascript
function square(depth, safe) {
  rapid({z: safe});
  rapid(0, 0);

  cut({z: depth});

  cut(1, 0);
  cut(1, 1);
  cut(0, 1);
  cut(0, 0);

  rapid({z: safe});
}

feed(400);

scale(3, 3);
rotate(Math.PI / 4);
translate(1, 1);
square(-1, 2);

loadIdentity();
scale(2, 2);
translate(0.5, 0.5);
square(-1, 2);
```

```
G21
F400
G0 Z2
G0 X1 Y1
G1 Z-1
G1 X3.12132 Y3.12132
G1 X1 Y5.242641
G1 X-1.12132 Y3.12132
G1 X1 Y1
G0 Z2
G0 X0.5 Y0.5
G1 Z-1
G1 X2.5
G1 Y2.5
G1 X0.5
G1 Y0.5
G0 Z2
%
```

[Figure 4](figures/figure4.png)
