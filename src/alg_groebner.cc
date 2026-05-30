#include <fflow/alg_groebner.hh>

#include <algorithm>

namespace fflow {

namespace {

  bool contains_(const std::vector<unsigned> & values, unsigned value)
  {
    return std::find(values.begin(), values.end(), value) != values.end();
  }

  bool same_support_(const std::vector<std::vector<PolyMonomial>> & a,
                     const std::vector<std::vector<PolyMonomial>> & b)
  {
    if (a.size() != b.size())
      return false;
    for (std::size_t i=0; i<a.size(); ++i) {
      if (a[i].size() != b[i].size())
        return false;
      for (std::size_t j=0; j<a[i].size(); ++j)
        if (!same_monomial(a[i][j], b[i][j]))
          return false;
    }
    return true;
  }

  void collect_support_(const std::vector<SparsePolynomial> & basis,
                        std::vector<std::vector<PolyMonomial>> & support)
  {
    support.clear();
    support.resize(basis.size());

    for (std::size_t poly=0; poly<basis.size(); ++poly) {
      for (const PolyTerm & term : basis[poly].terms) {
        bool seen = false;
        for (const PolyMonomial & known : support[poly]) {
          if (same_monomial(known, term.monomial)) {
            seen = true;
            break;
          }
        }
        if (!seen)
          support[poly].push_back(term.monomial);
      }

      std::sort(support[poly].begin(), support[poly].end(),
                [](const PolyMonomial & a, const PolyMonomial & b)
                {
                  return grevlex_less(b, a);
                });
    }
  }

  bool support_index_(const std::vector<PolyMonomial> & support,
                      const PolyMonomial & monomial,
                      std::size_t & index)
  {
    for (std::size_t i=0; i<support.size(); ++i) {
      if (same_monomial(support[i], monomial)) {
        index = i;
        return true;
      }
    }
    return false;
  }

  SparsePolynomial reorder_polynomial_(const SparsePolynomial & poly,
                                       const std::vector<unsigned> & order,
                                       UInt prime)
  {
    SparsePolynomial out;
    for (const PolyTerm & term : poly.terms) {
      std::vector<unsigned> exponents(order.size(), 0);
      for (std::size_t i=0; i<order.size(); ++i)
        exponents[i] = term.monomial.exponents[order[i]];
      out.add_term(term.coeff, exponents, prime);
    }
    out.normalize(prime);
    return out;
  }

  Ret filter_eliminated_basis_(const std::vector<SparsePolynomial> & in,
                               unsigned n_eliminated,
                               UInt prime,
                               std::vector<SparsePolynomial> & out)
  {
    out.clear();
    for (const SparsePolynomial & poly : in) {
      SparsePolynomial filtered;
      bool uses_eliminated = false;
      for (const PolyTerm & term : poly.terms) {
        for (unsigned i=0; i<n_eliminated; ++i) {
          if (term.monomial.exponents[i] != 0) {
            uses_eliminated = true;
            break;
          }
        }
        if (uses_eliminated)
          break;
      }

      if (uses_eliminated)
        continue;

      for (const PolyTerm & term : poly.terms) {
        std::vector<unsigned> exponents(
          term.monomial.exponents.begin() + n_eliminated,
          term.monomial.exponents.end());
        filtered.add_term(term.coeff, exponents, prime);
      }
      filtered.normalize(prime);
      if (!filtered.empty())
        out.push_back(filtered);
    }
    return SUCCESS;
  }

} // namespace

  Ret Groebner::init(const unsigned npars[], unsigned npars_size,
                     std::vector<std::string> && variables,
                     PolyTakePattern && ideal_pattern,
                     std::vector<unsigned> && eliminate_variables)
  {
    if (variables.empty()) {
      logerr("FFAlgNodeGroebner requires at least one polynomial variable");
      return FAILED;
    }
    if (ideal_pattern.empty()) {
      logerr("FFAlgNodeGroebner requires at least one ideal generator");
      return FAILED;
    }

    std::sort(eliminate_variables.begin(), eliminate_variables.end());
    if (std::unique(eliminate_variables.begin(), eliminate_variables.end()) !=
        eliminate_variables.end()) {
      logerr("FFAlgNodeGroebner received duplicate eliminated variables");
      return FAILED;
    }
    for (unsigned var : eliminate_variables) {
      if (var >= variables.size()) {
        logerr("FFAlgNodeGroebner eliminated variable index is out of range");
        return FAILED;
      }
    }
    if (!eliminate_variables.empty() &&
        eliminate_variables.size() >= variables.size()) {
      logerr("FFAlgNodeGroebner cannot eliminate all variables");
      return FAILED;
    }

    nparsin.resize(npars_size);
    std::vector<unsigned> input_lengths(npars_size);
    for (unsigned i=0; i<npars_size; ++i) {
      nparsin[i] = npars[i];
      input_lengths[i] = npars[i];
    }

    std::string error;
    if (validate_poly_take_pattern(ideal_pattern, input_lengths,
                                   variables.size(), &error) != SUCCESS) {
      logerr("Invalid Groebner ideal take pattern: " + error);
      return FAILED;
    }

    surviving_variables_.clear();
    for (unsigned i=0; i<variables.size(); ++i)
      if (!contains_(eliminate_variables, i))
        surviving_variables_.push_back(i);

    variables_ = std::move(variables);
    eliminate_variables_ = std::move(eliminate_variables);
    ideal_pattern_ = std::move(ideal_pattern);
    support_.clear();
    learned_slices_ = 0;
    nparsout = ~unsigned(0);
    return SUCCESS;
  }

  Ret Groebner::basis_from_inputs_(AlgInput xin[], Mod mod,
                                   std::vector<SparsePolynomial> & basis) const
  {
    const UInt prime = mod.n();
    std::vector<std::vector<UInt>> inputs(nparsin.size());
    for (std::size_t i=0; i<nparsin.size(); ++i)
      inputs[i].assign(xin[i], xin[i] + nparsin[i]);

    std::vector<SparsePolynomial> ideal;
    std::string error;

    if (expand_poly_take_pattern(ideal_pattern_, inputs, prime, ideal,
                                 &error) != SUCCESS) {
      logerr("Could not expand FFAlgNodeGroebner ideal pattern: " + error);
      return FAILED;
    }

    std::vector<unsigned> order;
    order.reserve(variables_.size());
    order.insert(order.end(), eliminate_variables_.begin(),
                 eliminate_variables_.end());
    order.insert(order.end(), surviving_variables_.begin(),
                 surviving_variables_.end());

    std::vector<std::string> msolve_variables;
    msolve_variables.reserve(order.size());
    for (unsigned idx : order)
      msolve_variables.push_back(variables_[idx]);

    std::vector<SparsePolynomial> msolve_ideal;
    msolve_ideal.reserve(ideal.size());
    for (const SparsePolynomial & poly : ideal)
      msolve_ideal.push_back(reorder_polynomial_(poly, order, prime));

    std::vector<SparsePolynomial> msolve_basis;
    MsolveResult trace;
    if (msolve_groebner(prime, msolve_variables, msolve_ideal,
                        msolve_options_, eliminate_variables_.size(),
                        msolve_basis, &trace) != SUCCESS) {
      logerr("FFAlgNodeGroebner msolve Groebner-basis computation failed: " +
             trace.error);
      return FAILED;
    }

    if (eliminate_variables_.empty()) {
      basis = std::move(msolve_basis);
      return SUCCESS;
    }

    if (filter_eliminated_basis_(msolve_basis, eliminate_variables_.size(),
                                 prime, basis) != SUCCESS)
      return FAILED;

    if (basis.empty()) {
      logerr("FFAlgNodeGroebner elimination produced no surviving polynomials");
      return FAILED;
    }

    return SUCCESS;
  }

  Ret Groebner::learn(Context *, AlgInput xin[], Mod mod, AlgorithmData *)
  {
    std::vector<SparsePolynomial> basis;
    if (basis_from_inputs_(xin, mod, basis) != SUCCESS) {
      support_.clear();
      learned_slices_ = 0;
      nparsout = ~unsigned(0);
      return FAILED;
    }

    std::vector<std::vector<PolyMonomial>> slice_support;
    collect_support_(basis, slice_support);

    if (learned_slices_ == 0 || nparsout == ~unsigned(0)) {
      support_ = slice_support;
      learned_slices_ = 1;
    } else if (!same_support_(support_, slice_support)) {
      logerr("FFAlgNodeGroebner learned an inconsistent monomial support");
      support_.clear();
      learned_slices_ = 0;
      nparsout = ~unsigned(0);
      return FAILED;
    } else {
      ++learned_slices_;
    }

    nparsout = 0;
    for (const auto & poly_support : support_)
      nparsout += poly_support.size();
    return SUCCESS;
  }

  Ret Groebner::evaluate(Context *, AlgInput xin[], Mod mod, AlgorithmData *,
                         UInt xout[]) const
  {
    if (nparsout == ~unsigned(0)) {
      logerr("FFAlgNodeGroebner evaluated before learning");
      return FAILED;
    }

    std::fill(xout, xout + nparsout, UInt(0));

    std::vector<SparsePolynomial> basis;
    if (basis_from_inputs_(xin, mod, basis) != SUCCESS)
      return FAILED;

    if (basis.size() != support_.size()) {
      logerr("FFAlgNodeGroebner runtime basis size differs from learning");
      return FAILED;
    }

    std::size_t offset = 0;
    for (std::size_t poly=0; poly<basis.size(); ++poly) {
      SparsePolynomial gb_poly = basis[poly];
      gb_poly.normalize(mod.n());
      for (const PolyTerm & term : gb_poly.terms) {
        std::size_t support_idx = 0;
        if (!support_index_(support_[poly], term.monomial, support_idx)) {
          logerr("FFAlgNodeGroebner runtime Groebner basis contains a monomial "
                 "outside the learned support");
          return FAILED;
        }
        xout[offset + support_idx] = term.coeff % mod.n();
      }
      offset += support_[poly].size();
    }

    return SUCCESS;
  }

} // namespace fflow
