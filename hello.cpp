#include <atomic>
#include <cstdint>
std::atomic<uint64_t> xx (0);
std::atomic<int> x;
std::atomic<short> y;
std::atomic<char> z;
int main() {
  ++z;
  ++y;

  uint64_t i = x.load(std::memory_order_relaxed);
  (void)i;
          volatile unsigned long val = 1;
        __sync_synchronize();
        __sync_val_compare_and_swap(&val, 1, 0);
        __sync_add_and_fetch(&val, 1);
        __sync_sub_and_fetch(&val, 1);
  return ++xx;
}