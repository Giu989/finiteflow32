#ifndef FFLOW_ALG_POLY_REDUCTION_HH
#define FFLOW_ALG_POLY_REDUCTION_HH

#include <fflow/algorithm.hh>
#include <fflow/poly_reduction.hh>

namespace fflow {

  class PolyDiv : public Algorithm {
  public:
    Ret init(const unsigned npars[], unsigned npars_size,
             std::vector<std::string> && variables,
             PolyTakePattern && target_pattern,
             PolyTakePattern && ideal_pattern);

    virtual Ret evaluate(Context * ctxt,
                         AlgInput xin[], Mod mod, AlgorithmData * data,
                         UInt xout[]) const override;

    virtual UInt min_learn_times() override
    {
      return learn_slices_;
    }

    virtual Ret learn(Context * ctxt, AlgInput xin[], Mod mod,
                      AlgorithmData * data) override;

    const std::vector<PolyMonomial> & basis() const
    {
      return basis_;
    }

  private:
    Ret normal_forms_from_inputs_(AlgInput xin[], Mod mod,
                                  std::vector<SparsePolynomial> & normal_forms)
      const;

  private:
    std::vector<std::string> variables_;
    PolyTakePattern target_pattern_;
    PolyTakePattern ideal_pattern_;
    std::vector<PolyMonomial> basis_;
    unsigned learn_slices_ = 2;
    unsigned learned_slices_ = 0;
    MsolveOptions msolve_options_;
  };

} // namespace fflow

#endif // FFLOW_ALG_POLY_REDUCTION_HH
