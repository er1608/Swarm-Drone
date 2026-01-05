#ifndef HAVE_DSP_H
#define HAVE_DSP_H

#include <complex>
#include <cmath>

// Return the average power of a vector.
template <class myType>
double sigpower(const myType v) {
  double r = 0;
  for (int t = 0; t < length(v); t++) {
    r += std::pow(real(v(t)), 2) + std::pow(imag(v(t)), 2);
  }
  return (r / length(v));
}

// Wrapers to properly scale fft and ifft output
#define idft(A) (ifft(A) * sqrt(length(A)))
#define dft(A)  (fft(A)  / sqrt(length(A)))

// Shift vector seq up by f Hz assuming that seq was sampled at fs Hz.
inline itpp::cvec fshift(const itpp::cvec &seq, const double f, const double fs) {
  double k = itpp::pi * f / (fs / 2);
  const uint32 len = length(seq);
  itpp::cvec r(len);

  for (uint32 t = 0; t < len; t++) {
    std::complex<double> coeff(std::cos(k * t), std::sin(k * t));  // ✅ FIX
    r(t) = seq(t) * coeff;
  }
  return r;
}

// Shift vector seq up by f Hz assuming that seq was sampled at 2 Hz.
inline itpp::cvec fshift(const itpp::cvec &seq, const double f) {
  return fshift(seq, f, 2);
}

inline void fshift_inplace(itpp::cvec &seq, const double f, const double fs) {
  double k = itpp::pi * f / (fs / 2);
  const uint32 len = length(seq);

  for (uint32 t = 0; t < len; t++) {
    std::complex<double> coeff(std::cos(k * t), std::sin(k * t));  // ✅ FIX
    seq(t) *= coeff;
  }
}

inline void fshift_inplace(itpp::cvec &seq, const double f) {
  fshift_inplace(seq, f, 2);
}

// Cyclically shift vector to the right by n samples.
template <class vectype>
void tshift(vectype &v, const double n) {
  ASSERT(n == itpp::floor_i(n));

  int ni = static_cast<int>(n);  // ✅ FIX signed

  if (ni >= 0) {
    vectype v_save = v.right(ni);
    for (int t = v.length() - 1; t >= ni; t--) {
      v[t] = v[t - ni];
    }
    for (int t = 0; t < ni; t++) {
      v[t] = v_save[t];
    }
  } else {
    ni = -ni;
    vectype v_save = v.left(ni);
    for (int t = 0; t < v.length() - ni; t++) {
      v[t] = v[t + ni];
    }
    for (int t = 0; t < ni; t++) {
      v[t + v.length() - ni] = v_save[t];
    }
  }
}

// Convert to/from dB and linear and power values
template <class myType>
myType db10(const myType s) {
  return (10 * log10(s));
}

template <class myType>
myType db20(const myType s) {
  return (20 * log10(s));
}

template <class myType>
myType udb10(const myType s) {
  myType result;
  result.set_length(length(s), false);
  for (int t = 0; t < length(s); t++) {
    result(t) = std::pow(10.0, s(t) / 10.0);  // ✅ FIX
  }
  return result;
}

inline double udb10(const double v) {
  return std::pow(10.0, v / 10.0);
}

template <class myType>
myType udb20(const myType s) {
  myType result;
  result.set_length(length(s), false);
  for (int t = 0; t < length(s); t++) {
    result(t) = std::pow(10.0, s(t) / 20.0);  // ✅ FIX
  }
  return result;
}

inline double udb20(const double v) {
  return std::pow(10.0, v / 20.0);
}

// Complex white Gaussian noise
inline itpp::cvec blnoise(const uint32 &n_samp) {
  return itpp::randn_c(n_samp);
}

// interp1, chi2cdf, interpft giữ nguyên

#endif
