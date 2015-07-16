# sed 's/alu.png/\.\.\/alu.png/' throttle_fixme.ac | sed 's/black.png/\.\.\/black.png/' | sed 's/greenishMetal.png/\.\.\/greenishMetal.png/' | sed 's/blueishMetal.png/\.\.\/blueishMetal.png/' | sed 's/brass.png/\.\.\/brass.png/' | sed 's/rubberGrip_brown_665e5a.png.png/\.\.\/rubberGrip_brown_665e5a.png.png/' | less -i > throttle.ac

# standard input
# sed 's/alu.png/\.\.\/alu.png/' | sed 's/black.png/\.\.\/black.png/' | sed 's/greenishMetal.png/\.\.\/greenishMetal.png/' | sed 's/blueishMetal.png/\.\.\/blueishMetal.png/' | sed 's/brass.png/\.\.\/brass.png/' | sed 's/rubberGrip_brown_665e5a.png/\.\.\/rubberGrip_brown_665e5a.png/' | sed 's/rubberGrip_black_1a1817.png/\.\.\/rubberGrip_black_1a1817.png/'

sed 's/alu.png/\.\.\/alu.png/' \
 | sed 's/black.png/\.\.\/black.png/' \
 | sed 's/greenishMetal.png/\.\.\/greenishMetal.png/' \
 | sed 's/blueishMetal.png/\.\.\/blueishMetal.png/' \
 | sed 's/brass.png/\.\.\/brass.png/' \
 | sed 's/rubberGrip_brown_665e5a.png/\.\.\/rubberGrip_brown_665e5a.png/' \
 | sed 's/rubberGrip_black_1a1817.png/\.\.\/rubberGrip_black_1a1817.png/' \
 | sed 's/black_1a1817_rubberGrip.png/\.\.\/black_1a1817_rubberGrip.png/' \
 | sed 's/black_hex191919_knurled_stronger.png/\.\.\/black_hex191919_knurled_stronger.png/' \
 | sed 's/black_hex191919_uniform.png/\.\.\/black_hex191919_uniform.png/' \
 | sed 's/black_hex191919_knurled_evenStronger.png/\.\.\/black_hex191919_knurled_evenStronger.png/' \
 | sed 's/almostWhite_ededed_dvsup_strong.png/\.\.\/almostWhite_ededed_dvsup_strong.png/' \
 | sed 's/black_hex191919_rubberGrip_2x.png/\.\.\/black_hex191919_rubberGrip_2x.png/'
 