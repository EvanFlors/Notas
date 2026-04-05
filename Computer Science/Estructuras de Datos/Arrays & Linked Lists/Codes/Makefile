# C Compiler
CC = gcc
CFLAGS = -Wall -std=c17

# C++ Compiler
CXX = g++
CXXFLAGS = -Wall -std=c++17

# Compile C files
%: %.c
	$(CC) $(CFLAGS) -o $@ $<

# Compile C++ files
%: %.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)
