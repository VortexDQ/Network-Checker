CXX      = g++
CXXFLAGS = -std=c++17 -O2 -Wall
TARGET   = netrepair
SRC      = src/main.cpp

# macOS: clang++ is default, both work
ifeq ($(shell uname), Darwin)
  CXX = clang++
endif

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SRC)
	@echo "Built: ./$(TARGET)"

install: $(TARGET)
	sudo cp $(TARGET) /usr/local/bin/
	@echo "Installed to /usr/local/bin/netrepair"

uninstall:
	sudo rm -f /usr/local/bin/netrepair

clean:
	rm -f $(TARGET)

.PHONY: all install uninstall clean
