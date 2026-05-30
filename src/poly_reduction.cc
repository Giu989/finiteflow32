#include <fflow/poly_reduction.hh>

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <fstream>
#include <map>
#include <sstream>
#include <sys/wait.h>
#include <unistd.h>

namespace fflow {

namespace {

  bool is_executable_(const std::string & path)
  {
    return !path.empty() && access(path.c_str(), X_OK) == 0;
  }

  std::string trim_(const std::string & s)
  {
    std::size_t begin = 0;
    while (begin < s.size() &&
           (s[begin] == ' ' || s[begin] == '\t' ||
            s[begin] == '\n' || s[begin] == '\r'))
      ++begin;

    std::size_t end = s.size();
    while (end > begin &&
           (s[end-1] == ' ' || s[end-1] == '\t' ||
            s[end-1] == '\n' || s[end-1] == '\r'))
      --end;

    return s.substr(begin, end - begin);
  }

  void set_error_(std::string * error, const std::string & msg)
  {
    if (error)
      *error = msg;
  }

  bool read_file_(const std::string & path, std::string & out)
  {
    std::ifstream file(path.c_str(), std::ios::in | std::ios::binary);
    if (!file)
      return false;

    std::ostringstream ss;
    ss << file.rdbuf();
    out = ss.str();
    return true;
  }

  bool write_file_(const std::string & path, const std::string & text)
  {
    std::ofstream file(path.c_str(), std::ios::out | std::ios::binary);
    if (!file)
      return false;
    file << text;
    return bool(file);
  }

  std::string shell_quote_(const std::string & path)
  {
    std::string out = "'";
    for (char c : path) {
      if (c == '\'')
        out += "'\\''";
      else
        out += c;
    }
    out += "'";
    return out;
  }

  std::string join_(const std::vector<std::string> & vals,
                    const std::string & sep)
  {
    std::string out;
    for (std::size_t i=0; i<vals.size(); ++i) {
      if (i)
        out += sep;
      out += vals[i];
    }
    return out;
  }

  std::string render_msolve_input_(UInt prime,
                                   const std::vector<std::string> & variables,
                                   const std::vector<std::string> & ideal,
                                   const std::vector<std::string> & targets)
  {
    std::ostringstream out;
    out << join_(variables, ",") << "\n";
    out << prime << "\n";

    std::vector<std::string> polys = ideal;
    polys.insert(polys.end(), targets.begin(), targets.end());
    for (std::size_t i=0; i<polys.size(); ++i) {
      out << polys[i];
      if (i + 1 != polys.size())
        out << ",";
      out << "\n";
    }

    return out.str();
  }

  bool make_temp_dir_(const std::string & base, std::string & out,
                      std::string * error)
  {
    std::string root = base;
    if (root.empty()) {
      const char * tmp = std::getenv("TMPDIR");
      root = tmp && tmp[0] ? tmp : "/tmp";
    }

    if (!root.empty() && root[root.size()-1] == '/')
      root.resize(root.size()-1);

    std::string templ = root + "/finiteflow32-msolve.XXXXXX";
    std::vector<char> buf(templ.begin(), templ.end());
    buf.push_back('\0');

    char * dir = mkdtemp(buf.data());
    if (!dir) {
      set_error_(error, std::string("could not create temporary directory: ") +
                 std::strerror(errno));
      return false;
    }

    out = dir;
    return true;
  }

  int normalized_system_status_(int status)
  {
    if (status == -1)
      return -1;
#ifdef WIFEXITED
    if (WIFEXITED(status))
      return WEXITSTATUS(status);
    if (WIFSIGNALED(status))
      return 128 + WTERMSIG(status);
#endif
    return status;
  }

  void cleanup_temp_(const MsolveResult & result)
  {
    if (!result.input_file.empty())
      std::remove(result.input_file.c_str());
    if (!result.output_file.empty())
      std::remove(result.output_file.c_str());
    if (!result.input_file.empty()) {
      std::string dir = result.input_file.substr(0, result.input_file.find_last_of('/'));
      std::remove((dir + "/stdout.txt").c_str());
      std::remove((dir + "/stderr.txt").c_str());
      rmdir(dir.c_str());
    }
  }

  bool parse_uint_(const std::string & text, UInt & out)
  {
    if (text.empty())
      return false;
    UInt val = 0;
    for (char c : text) {
      if (c < '0' || c > '9')
        return false;
      UInt digit = UInt(c - '0');
      UInt next = 10*val + digit;
      if (next < val)
        return false;
      val = next;
    }
    out = val;
    return true;
  }

  bool parse_unsigned_(const std::string & text, unsigned & out)
  {
    UInt val = 0;
    if (!parse_uint_(text, val) || val > UInt(~unsigned(0)))
      return false;
    out = unsigned(val);
    return true;
  }

  bool is_decimal_(const std::string & text)
  {
    if (text.empty())
      return false;
    for (char c : text)
      if (c < '0' || c > '9')
        return false;
    return true;
  }

  int find_variable_(const std::vector<std::string> & variables,
                     const std::string & name)
  {
    for (std::size_t i=0; i<variables.size(); ++i)
      if (variables[i] == name)
        return int(i);
    return -1;
  }

  Ret parse_factor_(const std::string & factor,
                    const std::vector<std::string> & variables,
                    UInt prime,
                    UInt & coeff,
                    std::vector<unsigned> & exponents,
                    std::string * error)
  {
    if (factor.empty()) {
      set_error_(error, "empty polynomial factor");
      return FAILED;
    }

    if (is_decimal_(factor)) {
      UInt val = 0;
      if (!parse_uint_(factor, val)) {
        set_error_(error, "invalid integer coefficient in msolve output");
        return FAILED;
      }
      coeff = UInt((FFU128(coeff) * (val % prime)) % prime);
      return SUCCESS;
    }

    std::size_t hat = factor.find('^');
    std::string name = hat == std::string::npos ? factor : factor.substr(0, hat);
    unsigned exp = 1;
    if (hat != std::string::npos) {
      if (!parse_unsigned_(factor.substr(hat + 1), exp)) {
        set_error_(error, "invalid monomial exponent in msolve output");
        return FAILED;
      }
    }

    int var = find_variable_(variables, name);
    if (var < 0) {
      set_error_(error, "unknown variable in msolve output: " + name);
      return FAILED;
    }

    exponents[std::size_t(var)] += exp;
    return SUCCESS;
  }

  void collect_basis_(const std::vector<SparsePolynomial> & normal_forms,
                      std::vector<PolyMonomial> & basis)
  {
    basis.clear();

    for (const SparsePolynomial & poly : normal_forms) {
      for (const PolyTerm & term : poly.terms) {
        bool seen = false;
        for (const PolyMonomial & monomial : basis) {
          if (same_monomial(monomial, term.monomial)) {
            seen = true;
            break;
          }
        }
        if (!seen)
          basis.push_back(term.monomial);
      }
    }

    std::sort(basis.begin(), basis.end(),
              [](const PolyMonomial & a, const PolyMonomial & b)
              {
                return grevlex_less(b, a);
              });
  }

  bool same_basis_(const std::vector<PolyMonomial> & a,
                   const std::vector<PolyMonomial> & b)
  {
    if (a.size() != b.size())
      return false;
    for (std::size_t i=0; i<a.size(); ++i)
      if (!same_monomial(a[i], b[i]))
        return false;
    return true;
  }

  void merge_basis_(std::vector<PolyMonomial> & basis,
                    const std::vector<PolyMonomial> & slice_basis)
  {
    for (const PolyMonomial & monomial : slice_basis) {
      bool seen = false;
      for (const PolyMonomial & known : basis) {
        if (same_monomial(known, monomial)) {
          seen = true;
          break;
        }
      }
      if (!seen)
        basis.push_back(monomial);
    }
    std::sort(basis.begin(), basis.end(),
              [](const PolyMonomial & a, const PolyMonomial & b)
              {
                return grevlex_less(b, a);
              });
  }

} // namespace

  bool find_msolve_executable(std::string & executable)
  {
    const char * from_env = std::getenv("MSOLVE");
    if (from_env && is_executable_(from_env)) {
      executable = from_env;
      return true;
    }

    const char * path_env = std::getenv("PATH");
    if (path_env) {
      std::string path(path_env);
      std::size_t begin = 0;
      while (begin <= path.size()) {
        std::size_t end = path.find(':', begin);
        if (end == std::string::npos)
          end = path.size();
        std::string dir = path.substr(begin, end - begin);
        if (!dir.empty()) {
          std::string candidate = dir + "/msolve";
          if (is_executable_(candidate)) {
            executable = candidate;
            return true;
          }
        }
        begin = end + 1;
      }
    }

    const char * common[] = {
      "/opt/homebrew/bin/msolve",
      "/usr/local/bin/msolve",
      "/usr/bin/msolve"
    };
    for (const char * candidate : common)
      if (is_executable_(candidate)) {
        executable = candidate;
        return true;
      }

    executable.clear();
    return false;
  }

  Ret split_msolve_normal_forms(const std::string & output,
                                std::vector<std::string> & normal_forms,
                                std::string * error)
  {
    normal_forms.clear();

    std::string text = trim_(output);
    if (text.empty()) {
      set_error_(error, "empty msolve output");
      return FAILED;
    }

    if (text[text.size()-1] != ':') {
      set_error_(error, "msolve output does not end with ':'");
      return FAILED;
    }
    text.resize(text.size()-1);
    text = trim_(text);

    if (text.size() < 2 || text[0] != '[' || text[text.size()-1] != ']') {
      set_error_(error, "msolve output is not a bracketed list");
      return FAILED;
    }

    std::string body = text.substr(1, text.size()-2);
    std::size_t begin = 0;
    while (begin <= body.size()) {
      std::size_t end = body.find(',', begin);
      if (end == std::string::npos)
        end = body.size();
      std::string poly = trim_(body.substr(begin, end - begin));
      if (!poly.empty())
        normal_forms.push_back(poly);
      begin = end + 1;
    }

    return SUCCESS;
  }

  Ret msolve_normal_forms_text(UInt prime,
                               const std::vector<std::string> & variables,
                               const std::vector<std::string> & ideal,
                               const std::vector<std::string> & targets,
                               const MsolveOptions & options,
                               MsolveResult & result)
  {
    result = MsolveResult();
    result.prime = prime;

    if (prime == 0 || prime >= (UInt(1) << 31)) {
      result.error = "msolve normal forms require a prime below 2^31";
      return FAILED;
    }
    if (variables.empty()) {
      result.error = "msolve input requires at least one variable";
      return FAILED;
    }
    if (ideal.empty()) {
      result.error = "msolve normal-form input requires at least one ideal generator";
      return FAILED;
    }
    if (targets.empty()) {
      result.error = "msolve normal-form input requires at least one target";
      return FAILED;
    }

    result.executable = options.executable;
    if (result.executable.empty() && !find_msolve_executable(result.executable)) {
      result.error = "msolve executable not found";
      return FAILED;
    }
    if (!is_executable_(result.executable)) {
      result.error = "msolve executable is not executable: " + result.executable;
      return FAILED;
    }

    std::string temp_dir;
    if (!make_temp_dir_(options.tmpdir, temp_dir, &result.error))
      return FAILED;

    result.input_file = temp_dir + "/input.ms";
    result.output_file = temp_dir + "/output.ms";
    const std::string stdout_file = temp_dir + "/stdout.txt";
    const std::string stderr_file = temp_dir + "/stderr.txt";

    result.input_text = render_msolve_input_(prime, variables, ideal, targets);
    if (!write_file_(result.input_file, result.input_text)) {
      result.error = "could not write msolve input file";
      if (!options.keep_files)
        cleanup_temp_(result);
      return FAILED;
    }

    result.command = shell_quote_(result.executable) +
      " -f " + shell_quote_(result.input_file) +
      " -o " + shell_quote_(result.output_file) +
      " -n " + std::to_string(targets.size()) +
      " -v 0 > " + shell_quote_(stdout_file) +
      " 2> " + shell_quote_(stderr_file);

    int status = std::system(result.command.c_str());
    int exit_code = normalized_system_status_(status);
    if (exit_code != 0) {
      std::string stderr_text;
      read_file_(stderr_file, stderr_text);
      result.error = "msolve failed with exit code " + std::to_string(exit_code);
      if (!stderr_text.empty())
        result.error += ": " + trim_(stderr_text);
      if (!options.keep_files)
        cleanup_temp_(result);
      return FAILED;
    }

    if (!read_file_(result.output_file, result.output_text)) {
      result.error = "could not read msolve output file";
      if (!options.keep_files)
        cleanup_temp_(result);
      return FAILED;
    }

    Ret ret = split_msolve_normal_forms(result.output_text, result.normal_forms,
                                        &result.error);

    if (!options.keep_files)
      cleanup_temp_(result);

    return ret;
  }

  unsigned PolyMonomial::degree() const
  {
    unsigned deg = 0;
    for (unsigned e : exponents)
      deg += e;
    return deg;
  }

  bool same_monomial(const PolyMonomial & a, const PolyMonomial & b)
  {
    return a.exponents == b.exponents;
  }

  bool grevlex_less(const PolyMonomial & a, const PolyMonomial & b)
  {
    unsigned adeg = a.degree();
    unsigned bdeg = b.degree();
    if (adeg != bdeg)
      return adeg < bdeg;

    const std::size_t n = std::min(a.exponents.size(), b.exponents.size());
    for (std::size_t ri=0; ri<n; ++ri) {
      std::size_t i = n - 1 - ri;
      if (a.exponents[i] != b.exponents[i])
        return a.exponents[i] > b.exponents[i];
    }

    return a.exponents.size() < b.exponents.size();
  }

  void SparsePolynomial::clear()
  {
    terms.clear();
  }

  bool SparsePolynomial::empty() const
  {
    return terms.empty();
  }

  Ret SparsePolynomial::add_term(UInt coeff,
                                 const std::vector<unsigned> & exponents,
                                 UInt prime)
  {
    if (prime == 0)
      return FAILED;

    coeff %= prime;
    if (coeff == 0)
      return SUCCESS;

    PolyTerm term;
    term.coeff = coeff;
    term.monomial = PolyMonomial(exponents);
    terms.push_back(term);
    return SUCCESS;
  }

  void SparsePolynomial::normalize(UInt prime)
  {
    std::map<std::vector<unsigned>, UInt> collected;
    for (const PolyTerm & term : terms) {
      UInt coeff = term.coeff % prime;
      if (!coeff)
        continue;
      UInt & slot = collected[term.monomial.exponents];
      slot = UInt((FFU128(slot) + coeff) % prime);
    }

    terms.clear();
    for (const auto & it : collected) {
      if (!it.second)
        continue;
      PolyTerm term;
      term.coeff = it.second;
      term.monomial = PolyMonomial(it.first);
      terms.push_back(term);
    }

    std::sort(terms.begin(), terms.end(),
              [](const PolyTerm & a, const PolyTerm & b)
              {
                return grevlex_less(a.monomial, b.monomial);
              });
  }

  UInt SparsePolynomial::coefficient_of(const PolyMonomial & monomial) const
  {
    for (const PolyTerm & term : terms)
      if (same_monomial(term.monomial, monomial))
        return term.coeff;
    return 0;
  }

  std::string SparsePolynomial::to_msolve(const std::vector<std::string> & variables,
                                          UInt prime) const
  {
    SparsePolynomial poly = *this;
    poly.normalize(prime);

    if (poly.terms.empty())
      return "0";

    std::ostringstream out;
    for (std::size_t i=0; i<poly.terms.size(); ++i) {
      const PolyTerm & term = poly.terms[i];
      if (i)
        out << "+";

      bool is_const = term.monomial.degree() == 0;
      if (is_const || term.coeff != 1)
        out << term.coeff;

      bool need_mul = !is_const && term.coeff != 1;
      for (std::size_t v=0; v<term.monomial.exponents.size(); ++v) {
        unsigned exp = term.monomial.exponents[v];
        if (!exp)
          continue;
        if (need_mul)
          out << "*";
        out << variables[v];
        if (exp != 1)
          out << "^" << exp;
        need_mul = true;
      }
    }

    return out.str();
  }

  bool same_polynomial(const SparsePolynomial & a,
                       const SparsePolynomial & b,
                       UInt prime)
  {
    SparsePolynomial aa = a;
    SparsePolynomial bb = b;
    aa.normalize(prime);
    bb.normalize(prime);
    if (aa.terms.size() != bb.terms.size())
      return false;
    for (std::size_t i=0; i<aa.terms.size(); ++i) {
      if (aa.terms[i].coeff != bb.terms[i].coeff ||
          !same_monomial(aa.terms[i].monomial, bb.terms[i].monomial))
        return false;
    }
    return true;
  }

  Ret parse_msolve_polynomial(const std::string & text,
                              const std::vector<std::string> & variables,
                              UInt prime,
                              SparsePolynomial & polynomial,
                              std::string * error)
  {
    polynomial.clear();
    if (prime == 0) {
      set_error_(error, "cannot parse polynomial over modulus zero");
      return FAILED;
    }

    std::string s;
    for (char c : text)
      if (!(c == ' ' || c == '\t' || c == '\n' || c == '\r'))
        s.push_back(c);

    if (s.empty() || s == "0")
      return SUCCESS;

    std::size_t i = 0;
    while (i < s.size()) {
      int sign = 1;
      if (s[i] == '+') {
        ++i;
      } else if (s[i] == '-') {
        sign = -1;
        ++i;
      }

      std::size_t begin = i;
      while (i < s.size() && s[i] != '+' && s[i] != '-')
        ++i;
      std::string term_text = s.substr(begin, i - begin);
      if (term_text.empty()) {
        set_error_(error, "empty term in msolve polynomial");
        return FAILED;
      }

      UInt coeff = 1;
      std::vector<unsigned> exponents(variables.size(), 0);
      std::size_t fbegin = 0;
      while (fbegin <= term_text.size()) {
        std::size_t fend = term_text.find('*', fbegin);
        if (fend == std::string::npos)
          fend = term_text.size();
        std::string factor = term_text.substr(fbegin, fend - fbegin);
        if (parse_factor_(factor, variables, prime, coeff, exponents, error)
            != SUCCESS)
          return FAILED;
        fbegin = fend + 1;
      }

      if (sign < 0 && coeff)
        coeff = prime - coeff;

      if (polynomial.add_term(coeff, exponents, prime) != SUCCESS) {
        set_error_(error, "could not add parsed polynomial term");
        return FAILED;
      }
    }

    polynomial.normalize(prime);
    return SUCCESS;
  }

  Ret parse_msolve_polynomial_list(const std::string & output,
                                   const std::vector<std::string> & variables,
                                   UInt prime,
                                   std::vector<SparsePolynomial> & polynomials,
                                   std::string * error)
  {
    polynomials.clear();
    std::vector<std::string> forms;
    Ret ret = split_msolve_normal_forms(output, forms, error);
    if (ret != SUCCESS)
      return ret;

    for (const std::string & form : forms) {
      SparsePolynomial poly;
      ret = parse_msolve_polynomial(form, variables, prime, poly, error);
      if (ret != SUCCESS)
        return ret;
      polynomials.push_back(poly);
    }

    return SUCCESS;
  }

  Ret msolve_normal_forms(UInt prime,
                          const std::vector<std::string> & variables,
                          const std::vector<SparsePolynomial> & ideal,
                          const std::vector<SparsePolynomial> & targets,
                          const MsolveOptions & options,
                          std::vector<SparsePolynomial> & normal_forms,
                          MsolveResult * trace)
  {
    normal_forms.clear();

    std::vector<std::string> ideal_text;
    for (const SparsePolynomial & poly : ideal)
      ideal_text.push_back(poly.to_msolve(variables, prime));

    std::vector<std::string> target_text;
    for (const SparsePolynomial & poly : targets)
      target_text.push_back(poly.to_msolve(variables, prime));

    MsolveResult result;
    Ret ret = msolve_normal_forms_text(prime, variables, ideal_text, target_text,
                                       options, result);
    if (ret != SUCCESS) {
      if (trace)
        *trace = result;
      return ret;
    }

    ret = parse_msolve_polynomial_list(result.output_text, variables, prime,
                                       normal_forms, &result.error);
    if (trace)
      *trace = result;
    return ret;
  }

  Ret make_poly_take_pattern_from_flat(
    unsigned nvars,
    const std::vector<unsigned> & polynomial_sizes,
    const std::vector<unsigned> & sources,
    const std::vector<unsigned> & exponents,
    PolyTakePattern & pattern,
    std::string * error)
  {
    pattern.clear();

    if (nvars == 0) {
      set_error_(error, "take pattern requires at least one variable");
      return FAILED;
    }

    unsigned total_terms = 0;
    for (unsigned size : polynomial_sizes)
      total_terms += size;

    if (sources.size() != std::size_t(2)*total_terms) {
      set_error_(error, "take pattern source array has the wrong size");
      return FAILED;
    }
    if (exponents.size() != std::size_t(nvars)*total_terms) {
      set_error_(error, "take pattern exponent array has the wrong size");
      return FAILED;
    }

    pattern.resize(polynomial_sizes.size());
    std::size_t term_idx = 0;
    for (std::size_t poly=0; poly<polynomial_sizes.size(); ++poly) {
      pattern[poly].resize(polynomial_sizes[poly]);
      for (std::size_t j=0; j<polynomial_sizes[poly]; ++j, ++term_idx) {
        PolyTakeTerm & term = pattern[poly][j];
        term.input_node = sources[2*term_idx];
        term.output_index = sources[2*term_idx + 1];
        term.monomial.exponents.assign(nvars, 0);
        for (unsigned v=0; v<nvars; ++v)
          term.monomial.exponents[v] = exponents[term_idx*nvars + v];
      }
    }

    return SUCCESS;
  }

  Ret validate_poly_take_pattern(const PolyTakePattern & pattern,
                                 const std::vector<unsigned> & input_lengths,
                                 unsigned nvars,
                                 std::string * error)
  {
    if (nvars == 0) {
      set_error_(error, "take pattern requires at least one variable");
      return FAILED;
    }

    for (const PolyTakePolynomial & poly : pattern) {
      for (const PolyTakeTerm & term : poly) {
        if (term.input_node >= input_lengths.size()) {
          set_error_(error, "take pattern input node index out of range");
          return FAILED;
        }
        if (term.output_index >= input_lengths[term.input_node]) {
          set_error_(error, "take pattern output index out of range");
          return FAILED;
        }
        if (term.monomial.exponents.size() != nvars) {
          set_error_(error, "take pattern monomial has wrong variable count");
          return FAILED;
        }
      }
    }

    return SUCCESS;
  }

  Ret expand_poly_take_pattern(const PolyTakePattern & pattern,
                               const std::vector<std::vector<UInt>> & inputs,
                               UInt prime,
                               std::vector<SparsePolynomial> & polynomials,
                               std::string * error)
  {
    polynomials.clear();

    if (prime == 0) {
      set_error_(error, "cannot expand take pattern over modulus zero");
      return FAILED;
    }

    std::vector<unsigned> input_lengths(inputs.size());
    for (std::size_t i=0; i<inputs.size(); ++i)
      input_lengths[i] = unsigned(inputs[i].size());

    unsigned nvars = 0;
    for (const PolyTakePolynomial & poly : pattern)
      for (const PolyTakeTerm & term : poly)
        nvars = std::max<unsigned>(nvars, term.monomial.exponents.size());

    if (validate_poly_take_pattern(pattern, input_lengths, nvars, error)
        != SUCCESS)
      return FAILED;

    polynomials.resize(pattern.size());
    for (std::size_t poly_idx=0; poly_idx<pattern.size(); ++poly_idx) {
      SparsePolynomial & poly = polynomials[poly_idx];
      for (const PolyTakeTerm & term : pattern[poly_idx]) {
        UInt coeff = inputs[term.input_node][term.output_index] % prime;
        if (poly.add_term(coeff, term.monomial.exponents, prime) != SUCCESS) {
          set_error_(error, "could not add take-pattern term");
          return FAILED;
        }
      }
      poly.normalize(prime);
    }

    return SUCCESS;
  }

  Ret learn_poly_reduction_basis(
    UInt prime,
    const std::vector<std::string> & variables,
    const PolyTakePattern & target_pattern,
    const PolyTakePattern & ideal_pattern,
    const std::vector<std::vector<std::vector<UInt>>> & input_slices,
    const PolyReductionLearnOptions & options,
    PolyReductionLearnResult & result)
  {
    result = PolyReductionLearnResult();
    result.prime = prime;

    if (prime == 0 || prime >= (UInt(1) << 31)) {
      result.error = "poly-reduction learning requires a prime below 2^31";
      return FAILED;
    }
    if (variables.empty()) {
      result.error = "poly-reduction learning requires at least one variable";
      return FAILED;
    }
    if (target_pattern.empty()) {
      result.error = "poly-reduction learning requires a target take pattern";
      return FAILED;
    }
    if (ideal_pattern.empty()) {
      result.error = "poly-reduction learning requires an ideal take pattern";
      return FAILED;
    }
    if (input_slices.empty()) {
      result.error = "poly-reduction learning requires at least one input slice";
      return FAILED;
    }

    for (std::size_t slice=0; slice<input_slices.size(); ++slice) {
      const std::vector<std::vector<UInt>> & inputs = input_slices[slice];
      std::vector<SparsePolynomial> targets;
      std::vector<SparsePolynomial> ideal;
      std::string error;

      if (expand_poly_take_pattern(target_pattern, inputs, prime, targets,
                                   &error) != SUCCESS) {
        result.error = "could not expand target take pattern at learning slice " +
          std::to_string(slice) + ": " + error;
        return FAILED;
      }

      if (expand_poly_take_pattern(ideal_pattern, inputs, prime, ideal,
                                   &error) != SUCCESS) {
        result.error = "could not expand ideal take pattern at learning slice " +
          std::to_string(slice) + ": " + error;
        return FAILED;
      }

      std::vector<SparsePolynomial> normal_forms;
      MsolveResult trace;
      if (msolve_normal_forms(prime, variables, ideal, targets, options.msolve,
                              normal_forms, &trace) != SUCCESS) {
        result.traces.push_back(trace);
        result.error = "msolve normal-form learning failed at slice " +
          std::to_string(slice) + ": " + trace.error;
        return FAILED;
      }

      result.traces.push_back(trace);
      result.normal_forms_by_slice.push_back(normal_forms);

      std::vector<PolyMonomial> slice_basis;
      collect_basis_(normal_forms, slice_basis);
      result.basis_by_slice.push_back(slice_basis);

      if (slice == 0) {
        result.basis = slice_basis;
      } else {
        if (options.require_consistent_basis &&
            !same_basis_(result.basis, slice_basis)) {
          result.error = "inconsistent learned monomial basis at learning slice " +
            std::to_string(slice);
          return FAILED;
        }
        merge_basis_(result.basis, slice_basis);
      }
    }

    result.output_size = target_pattern.size() * result.basis.size();
    return SUCCESS;
  }

} // namespace fflow
