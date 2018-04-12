all:
	clang++ -c main.mm -o main.o -fobjc-arc
	clang++ -c object.mm -o object.o
	clang++ -c vendor.mm -o vendor.o
	clang++ object.o vendor.o main.o -o arc -framework Foundation