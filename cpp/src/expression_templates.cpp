#include <iostream>

struct RuntimeCalc {
  double val;

  static RuntimeCalc init(double initValue) { return RuntimeCalc{initValue}; }

  RuntimeCalc add(const RuntimeCalc &other) const { return {val + other.val}; }
  RuntimeCalc sub(const RuntimeCalc &other) const { return {val - other.val}; }
  RuntimeCalc mul(const RuntimeCalc &other) const { return {val * other.val}; }
  RuntimeCalc div(const RuntimeCalc &other) const { return {val / other.val}; }
};

struct Add {
  static inline double calc(double left, double right) { return left + right; }
};
struct Sub {
  static inline double calc(double left, double right) { return left - right; }
};
struct Mul {
  static inline double calc(double left, double right) { return left * right; }
};
struct Div {
  static inline double calc(double left, double right) { return left / right; }
};

template <typename FirstOp, typename SecondOp, typename ThirdOp>
struct CompileTimeCalc {
  double calculate(double init, double a, double b, double c) {
    double first = FirstOp::calc(init, a);
    double second = SecondOp::calc(first, b);
    return ThirdOp::calc(second, c);
  }
};

int runtime() {

  double input[4];

  std::cout << "---- runtime ----" << std::endl;
  std::cout << "Enter 4 dynamic numbers (init, a, b, c): ";

  if (!(std::cin >> input[0] >> input[1] >> input[2] >> input[3]))
    return 1;

  RuntimeCalc calcA{input[1]}, calcB{input[2]}, calcC{input[3]};

  RuntimeCalc r = RuntimeCalc::init(input[0]);

  // force operator precedence to be the same as the comptime version
  RuntimeCalc result = r.add(calcA).mul(calcB).div(calcC);

  std::cout << "Runtime Result: " << result.val << "\n";

  return 0;
}

int comptime() {

  double start, a, b, c;

  std::cout << "---- comptime ----" << std::endl;
  std::cout << "Enter 4 dynamic numbers (init, a, b, c): ";

  if (!(std::cin >> start >> a >> b >> c))
    return 1;

  CompileTimeCalc<Add, Mul, Div> compCalculator;

  double result = compCalculator.calculate(start, a, b, c);

  std::cout << "Comptime Result: " << result << "\n";

  return 0;
}

int main() {
  runtime();
  comptime();
}
