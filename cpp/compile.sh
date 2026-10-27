default:
	rm -rf build
	mkdir build
	cd build
	cmake .. -DOptimise=ON
	make

