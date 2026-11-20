.PHONY: configure build test selfplay python-test verify list
configure:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
build: configure
	cmake --build build --parallel
test: build
	ctest --test-dir build --output-on-failure
	python3 -m unittest discover -s Training/tests -v
selfplay: build
	./build/Engine/gomoku_cli --selfplay --games 2 --ms 5
verify:
	python3 Scripts/verify_package.py
list:
	python3 Scripts/migrate_from_veillink.py --help
