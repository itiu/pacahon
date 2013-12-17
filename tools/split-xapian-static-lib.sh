ar x libxapian.a
l1=`ar t libxapian.a |  grep brass`
l2=`ar t libxapian.a |  grep flint`

ar rvs libxapian-backend.a $l1 $l2

rm $l1
rm $l2

ar rvs libxapian-main.a *.o

rm *.o
