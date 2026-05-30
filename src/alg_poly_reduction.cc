#include <fflow/alg_poly_reduction.hh>

#include <algorithm>

namespace fflow {

namespace {

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

    std::sort(basis.begin(), basis.end(), grevlex_less);
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

  bool basis_index_(const std::vector<PolyMonomial> & basis,
                    const PolyMonomial & monomial,
                    std::size_t & index)
  {
    for (std::size_t i=0; i<basis.size(); ++i) {
      if (same_monomial(basis[i], monomial)) {
        index = i;
        return true;
      }
    }
    return false;
  }

} // namespace

  Ret PolyDiv::init(const unsigned npars[], unsigned npars_size,
                    std::vector<std::string> && variables,
                    PolyTakePattern && target_pattern,
                    PolyTakePattern && ideal_pattern)
  {
    if (variables.empty()) {
      logerr("FFAlgNodePolyDiv requires at least one polynomial variable");
      return FAILED;
    }
    if (target_pattern.empty()) {
      logerr("FFAlgNodePolyDiv requires at least one target polynomial");
      return FAILED;
    }
    if (ideal_pattern.empty()) {
      logerr("FFAlgNodePolyDiv requires at least one ideal generator");
      return FAILED;
    }

    nparsin.resize(npars_size);
    std::vector<unsigned> input_lengths(npars_size);
    for (unsigned i=0; i<npars_size; ++i) {
      nparsin[i] = npars[i];
      input_lengths[i] = npars[i];
    }

    std::string error;
    if (validate_poly_take_pattern(target_pattern, input_lengths,
                                   variables.size(), &error) != SUCCESS) {
      logerr("Invalid target take pattern: " + error);
      return FAILED;
    }
    if (validate_poly_take_pattern(ideal_pattern, input_lengths,
                                   variables.size(), &error) != SUCCESS) {
      logerr("Invalid ideal take pattern: " + error);
      return FAILED;
    }

    variables_ = std::move(variables);
    target_pattern_ = std::move(target_pattern);
    ideal_pattern_ = std::move(ideal_pattern);
    basis_.clear();
    learned_slices_ = 0;
    nparsout = ~unsigned(0);
    return SUCCESS;
  }

  Ret PolyDiv::normal_forms_from_inputs_(
    AlgInput xin[], Mod mod, std::vector<SparsePolynomial> & normal_forms)
    const
  {
    const UInt prime = mod.n();
    std::vector<std::vector<UInt>> inputs(nparsin.size());
    for (std::size_t i=0; i<nparsin.size(); ++i)
      inputs[i].assign(xin[i], xin[i] + nparsin[i]);

    std::vector<SparsePolynomial> targets;
    std::vector<SparsePolynomial> ideal;
    std::string error;

    if (expand_poly_take_pattern(target_pattern_, inputs, prime, targets,
                                 &error) != SUCCESS) {
      logerr("Could not expand FFAlgNodePolyDiv target pattern: " + error);
      return FAILED;
    }
    if (expand_poly_take_pattern(ideal_pattern_, inputs, prime, ideal,
                                 &error) != SUCCESS) {
      logerr("Could not expand FFAlgNodePolyDiv ideal pattern: " + error);
      return FAILED;
    }

    MsolveResult trace;
    if (msolve_normal_forms(prime, variables_, ideal, targets,
                            msolve_options_, normal_forms, &trace)
        != SUCCESS) {
      logerr("FFAlgNodePolyDiv msolve normal-form computation failed: " +
             trace.error);
      return FAILED;
    }
    if (normal_forms.size() != target_pattern_.size()) {
      logerr("FFAlgNodePolyDiv msolve returned the wrong number of targets");
      return FAILED;
    }

    return SUCCESS;
  }

  Ret PolyDiv::learn(Context *, AlgInput xin[], Mod mod, AlgorithmData *)
  {
    std::vector<SparsePolynomial> normal_forms;
    if (normal_forms_from_inputs_(xin, mod, normal_forms) != SUCCESS) {
      basis_.clear();
      learned_slices_ = 0;
      nparsout = ~unsigned(0);
      return FAILED;
    }

    std::vector<PolyMonomial> slice_basis;
    collect_basis_(normal_forms, slice_basis);

    if (learned_slices_ == 0 || nparsout == ~unsigned(0)) {
      basis_ = slice_basis;
      learned_slices_ = 1;
    } else if (!same_basis_(basis_, slice_basis)) {
      logerr("FFAlgNodePolyDiv learned an inconsistent monomial basis");
      basis_.clear();
      learned_slices_ = 0;
      nparsout = ~unsigned(0);
      return FAILED;
    } else {
      ++learned_slices_;
    }

    nparsout = target_pattern_.size() * basis_.size();
    return SUCCESS;
  }

  Ret PolyDiv::evaluate(Context *, AlgInput xin[], Mod mod, AlgorithmData *,
                        UInt xout[]) const
  {
    if (nparsout == ~unsigned(0)) {
      logerr("FFAlgNodePolyDiv evaluated before learning");
      return FAILED;
    }

    std::fill(xout, xout + nparsout, UInt(0));

    std::vector<SparsePolynomial> normal_forms;
    if (normal_forms_from_inputs_(xin, mod, normal_forms) != SUCCESS)
      return FAILED;

    const std::size_t basis_size = basis_.size();
    for (std::size_t target=0; target<normal_forms.size(); ++target) {
      SparsePolynomial poly = normal_forms[target];
      poly.normalize(mod.n());
      for (const PolyTerm & term : poly.terms) {
        std::size_t basis_idx = 0;
        if (!basis_index_(basis_, term.monomial, basis_idx)) {
          logerr("FFAlgNodePolyDiv runtime normal form contains a monomial "
                 "outside the learned basis");
          return FAILED;
        }
        xout[target*basis_size + basis_idx] = term.coeff % mod.n();
      }
    }

    return SUCCESS;
  }

} // namespace fflow
