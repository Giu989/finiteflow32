#ifndef FFLOW_POLY_REDUCTION_HH
#define FFLOW_POLY_REDUCTION_HH

#include <fflow/common.hh>

#include <cstddef>
#include <string>
#include <vector>

namespace fflow {

  struct MsolveOptions {
    std::string executable;
    std::string tmpdir;
    bool keep_files = false;
  };

  struct MsolveResult {
    UInt prime = 0;
    std::string executable;
    std::string input_file;
    std::string output_file;
    std::string input_text;
    std::string output_text;
    std::string command;
    std::string error;
    std::vector<std::string> normal_forms;
  };

  bool find_msolve_executable(std::string & executable);

  Ret split_msolve_normal_forms(const std::string & output,
                                std::vector<std::string> & normal_forms,
                                std::string * error = nullptr);

  Ret msolve_normal_forms_text(UInt prime,
                               const std::vector<std::string> & variables,
                               const std::vector<std::string> & ideal,
                               const std::vector<std::string> & targets,
                               const MsolveOptions & options,
                               MsolveResult & result);

  struct PolyMonomial {
    std::vector<unsigned> exponents;

    PolyMonomial() {}
    explicit PolyMonomial(const std::vector<unsigned> & exp)
      : exponents(exp) {}

    unsigned degree() const;
  };

  struct PolyTerm {
    UInt coeff = 0;
    PolyMonomial monomial;
  };

  bool same_monomial(const PolyMonomial & a, const PolyMonomial & b);
  bool grevlex_less(const PolyMonomial & a, const PolyMonomial & b);

  class SparsePolynomial {
  public:
    std::vector<PolyTerm> terms;

    void clear();
    bool empty() const;
    Ret add_term(UInt coeff, const std::vector<unsigned> & exponents,
                 UInt prime);
    void normalize(UInt prime);
    UInt coefficient_of(const PolyMonomial & monomial) const;
    std::string to_msolve(const std::vector<std::string> & variables,
                          UInt prime) const;
  };

  bool same_polynomial(const SparsePolynomial & a,
                       const SparsePolynomial & b,
                       UInt prime);

  Ret parse_msolve_polynomial(const std::string & text,
                              const std::vector<std::string> & variables,
                              UInt prime,
                              SparsePolynomial & polynomial,
                              std::string * error = nullptr);

  Ret parse_msolve_polynomial_list(const std::string & output,
                                   const std::vector<std::string> & variables,
                                   UInt prime,
                                   std::vector<SparsePolynomial> & polynomials,
                                   std::string * error = nullptr);

  Ret msolve_normal_forms(UInt prime,
                          const std::vector<std::string> & variables,
                          const std::vector<SparsePolynomial> & ideal,
                          const std::vector<SparsePolynomial> & targets,
                          const MsolveOptions & options,
                          std::vector<SparsePolynomial> & normal_forms,
                          MsolveResult * trace = nullptr);

  Ret split_msolve_bracketed_polynomial_list(
    const std::string & output,
    std::vector<std::string> & polynomials,
    std::string * error = nullptr);

  Ret msolve_groebner_text(UInt prime,
                           const std::vector<std::string> & variables,
                           const std::vector<std::string> & ideal,
                           const MsolveOptions & options,
                           unsigned elimination_count,
                           MsolveResult & result);

  Ret msolve_groebner(UInt prime,
                      const std::vector<std::string> & variables,
                      const std::vector<SparsePolynomial> & ideal,
                      const MsolveOptions & options,
                      unsigned elimination_count,
                      std::vector<SparsePolynomial> & basis,
                      MsolveResult * trace = nullptr);

  struct PolyTakeTerm {
    unsigned input_node = 0;
    unsigned output_index = 0;
    PolyMonomial monomial;

    PolyTakeTerm() {}
    PolyTakeTerm(unsigned input, unsigned output, const PolyMonomial & mon)
      : input_node(input), output_index(output), monomial(mon) {}
  };

  typedef std::vector<PolyTakeTerm> PolyTakePolynomial;
  typedef std::vector<PolyTakePolynomial> PolyTakePattern;

  Ret make_poly_take_pattern_from_flat(
    unsigned nvars,
    const std::vector<unsigned> & polynomial_sizes,
    const std::vector<unsigned> & sources,
    const std::vector<unsigned> & exponents,
    PolyTakePattern & pattern,
    std::string * error = nullptr);

  Ret validate_poly_take_pattern(const PolyTakePattern & pattern,
                                 const std::vector<unsigned> & input_lengths,
                                 unsigned nvars,
                                 std::string * error = nullptr);

  Ret expand_poly_take_pattern(const PolyTakePattern & pattern,
                               const std::vector<std::vector<UInt>> & inputs,
                               UInt prime,
                               std::vector<SparsePolynomial> & polynomials,
                               std::string * error = nullptr);

  struct PolyReductionLearnOptions {
    MsolveOptions msolve;
    bool require_consistent_basis = true;
  };

  struct PolyReductionLearnResult {
    UInt prime = 0;
    std::size_t output_size = 0;
    std::vector<PolyMonomial> basis;
    std::vector<std::vector<PolyMonomial>> basis_by_slice;
    std::vector<std::vector<SparsePolynomial>> normal_forms_by_slice;
    std::vector<MsolveResult> traces;
    std::string error;
  };

  Ret learn_poly_reduction_basis(
    UInt prime,
    const std::vector<std::string> & variables,
    const PolyTakePattern & target_pattern,
    const PolyTakePattern & ideal_pattern,
    const std::vector<std::vector<std::vector<UInt>>> & input_slices,
    const PolyReductionLearnOptions & options,
    PolyReductionLearnResult & result);

} // namespace fflow

#endif // FFLOW_POLY_REDUCTION_HH
