using Base.Test

import LightTable: round3

pi

float(pi)

100pi
pi/10000

@test round3(1pi) == "3.142"
@test round3(100pi) == "314.159"
@test round3(pi/10000) == "0.000314"
@test round3(-1/0.999) == "-1.001"
@test round3(1/9.95) == "0.101"
@test round3(1.9999) == "2.000"
@test round3(0.09999) == "0.100" # should probably be 0.1000, but that's a minor problem
@test round3(-1.1299e-6) == "-1.130e-6"