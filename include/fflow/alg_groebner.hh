#ifndef FFLOW_ALG_GROEBNER_HH
#define FFLOW_ALG_GROEBNER_HH

#include <fflow/algorithm.hh>
#include <fflow/poly_reduction.hh>

namespace fflow {

  class Groebner : public Algorithm {
  public:
    Ret init(const unsigned npars[], unsigned npars_size,
             std::vector<std::string> && variables,
             PolyTakePattern && ideal_pattern,
             std::vector<unsigned> && eliminate_variables);

    virtual Ret evaluate(Context * ctxt,
                         AlgInput xin[], Mod mod, AlgorithmData * data,
                         UInt xout[]) const override;

    virtual UInt min_learn_times() override
    {
      return learn_slices_;
    }

    virtual Ret learn(Context * ctxt, AlgInput xin[], Mod mod,
                      AlgorithmData * data) override;

    const std::vector<std::vector<PolyMonomial>> & support() const
    {
      return support_;
    }

  private:
    Ret basis_from_inputs_(AlgInput xin[], Mod mod,
                           std::vector<SparsePolynomial> & basis) const;

  private:
    std::vector<std::string> variables_;
    std::vector<unsigned> eliminate_variables_;
    std::vector<unsigned> surviving_variables_;
    PolyTakePattern ideal_pattern_;
    std::vector<std::vector<PolyMonomial>> support_;
    unsigned learn_slices_ = 2;
    unsigned learned_slices_ = 0;
    MsolveOptions msolve_options_;
  };

} // namespace fflow

#endif // FFLOW_ALG_GROEBNER_HH
