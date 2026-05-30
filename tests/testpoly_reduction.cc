#include <fflow/poly_reduction.hh>
#include <fflow/primes.hh>

#include <algorithm>
#include <iostream>

using namespace fflow;

namespace {

void require(bool ok, const char * what)
{
  if (!ok) {
    std::cerr << "poly reduction test failed: " << what << "\n";
    std::exit(1);
  }
}

void require_ret(Ret ret, const char * what, const std::string & error = "")
{
  if (ret != SUCCESS) {
    std::cerr << "poly reduction test failed: " << what;
    if (!error.empty())
      std::cerr << ": " << error;
    std::cerr << "\n";
    std::exit(1);
  }
}

void test_split_msolve_output()
{
  std::vector<std::string> forms;
  std::string error;
  require_ret(split_msolve_normal_forms("[1*y^1+1,\n0]:", forms, &error),
              "split msolve output", error);
  require(forms.size() == 2, "normal-form count");
  require(forms[0] == "1*y^1+1", "first normal form text");
  require(forms[1] == "0", "second normal form text");
}

void test_msolve_text_prototype()
{
  MsolveOptions options;
  MsolveResult result;
  const UInt prime = BIG_UINT_PRIMES[0];

  require_ret(msolve_normal_forms_text(
                prime,
                {"x", "y"},
                {"x^2+y", "x*y+1"},
                {"x^3+y", "x^2*y+x"},
                options,
                result),
              "msolve text normal-form prototype", result.error);

  require(result.prime == prime, "msolve result kept active prime");
  require(result.input_text.find(std::to_string(prime)) != std::string::npos,
          "msolve input text contains active prime");
  require(result.normal_forms.size() == 2, "msolve normal-form count");
  require(result.normal_forms[0] == "1*y^1+1",
          "msolve first reference normal form");
  require(result.normal_forms[1] == "0",
          "msolve second reference normal form");
}

SparsePolynomial make_poly(UInt prime,
                           std::initializer_list<std::pair<UInt, std::vector<unsigned>>> terms)
{
  SparsePolynomial poly;
  for (const auto & term : terms)
    require_ret(poly.add_term(term.first, term.second, prime),
                "add test polynomial term");
  poly.normalize(prime);
  return poly;
}

void test_polynomial_representation()
{
  const UInt prime = BIG_UINT_PRIMES[0];

  SparsePolynomial poly;
  require_ret(poly.add_term(2, {2, 0}, prime), "add x^2 term");
  require_ret(poly.add_term(prime - 1, {2, 0}, prime), "add -x^2 term");
  require_ret(poly.add_term(5, {0, 0}, prime), "add constant term");
  poly.normalize(prime);

  require(poly.terms.size() == 2, "normalization combines like terms");
  require(poly.coefficient_of(PolyMonomial({2, 0})) == 1,
          "combined x^2 coefficient");
  require(poly.coefficient_of(PolyMonomial({0, 0})) == 5,
          "constant coefficient");
  require(poly.to_msolve({"x", "y"}, prime) == "5+x^2",
          "deterministic msolve rendering");
}

void test_grevlex_order()
{
  std::vector<PolyMonomial> mons = {
    PolyMonomial({1, 1}),
    PolyMonomial({0, 0}),
    PolyMonomial({2, 0}),
    PolyMonomial({1, 0}),
    PolyMonomial({0, 1}),
    PolyMonomial({0, 2})
  };

  std::sort(mons.begin(), mons.end(), grevlex_less);

  std::vector<PolyMonomial> expected = {
    PolyMonomial({0, 0}),
    PolyMonomial({0, 1}),
    PolyMonomial({1, 0}),
    PolyMonomial({0, 2}),
    PolyMonomial({1, 1}),
    PolyMonomial({2, 0})
  };

  require(mons.size() == expected.size(), "grevlex sorted size");
  for (std::size_t i=0; i<mons.size(); ++i)
    require(same_monomial(mons[i], expected[i]), "grevlex sorted order");
}

void test_msolve_parser()
{
  const UInt prime = BIG_UINT_PRIMES[0];

  SparsePolynomial poly;
  std::string error;
  require_ret(parse_msolve_polynomial("1*y^1+1", {"x", "y"}, prime,
                                      poly, &error),
              "parse msolve polynomial", error);

  SparsePolynomial expected = make_poly(prime, {
      {1, {0, 1}},
      {1, {0, 0}}
    });
  require(same_polynomial(poly, expected, prime), "parsed polynomial content");

  std::vector<SparsePolynomial> list;
  require_ret(parse_msolve_polynomial_list("[1*y^1+1,\n0]:", {"x", "y"},
                                          prime, list, &error),
              "parse msolve polynomial list", error);
  require(list.size() == 2, "parsed polynomial list size");
  require(same_polynomial(list[0], expected, prime),
          "parsed first list polynomial");
  require(list[1].empty(), "parsed zero polynomial");
}

void test_msolve_polynomial_prototype()
{
  const UInt prime = BIG_UINT_PRIMES[0];
  const std::vector<std::string> vars = {"x", "y"};

  std::vector<SparsePolynomial> ideal = {
    make_poly(prime, {{1, {2, 0}}, {1, {0, 1}}}),
    make_poly(prime, {{1, {1, 1}}, {1, {0, 0}}})
  };
  std::vector<SparsePolynomial> targets = {
    make_poly(prime, {{1, {3, 0}}, {1, {0, 1}}}),
    make_poly(prime, {{1, {2, 1}}, {1, {1, 0}}})
  };

  MsolveOptions options;
  std::vector<SparsePolynomial> normal_forms;
  MsolveResult trace;
  require_ret(msolve_normal_forms(prime, vars, ideal, targets, options,
                                  normal_forms, &trace),
              "msolve polynomial normal-form prototype", trace.error);

  SparsePolynomial expected0 = make_poly(prime, {
      {1, {0, 1}},
      {1, {0, 0}}
    });
  SparsePolynomial expected1;

  require(normal_forms.size() == 2, "parsed normal-form count");
  require(same_polynomial(normal_forms[0], expected0, prime),
          "first parsed normal form");
  require(same_polynomial(normal_forms[1], expected1, prime),
          "second parsed normal form");
}

void test_take_pattern_expansion()
{
  const UInt prime = BIG_UINT_PRIMES[0];

  PolyTakePattern pattern = {
    {
      PolyTakeTerm{0, 0, PolyMonomial({2, 1})}
    },
    {
      PolyTakeTerm{0, 0, PolyMonomial({0, 0})},
      PolyTakeTerm{0, 1, PolyMonomial({3, 0})}
    },
    {
      PolyTakeTerm{2, 1, PolyMonomial({0, 2})}
    }
  };

  std::vector<std::vector<UInt>> inputs = {
    {5, 7},
    {11, 13, 17},
    {19, 23}
  };

  std::vector<SparsePolynomial> polys;
  std::string error;
  require_ret(expand_poly_take_pattern(pattern, inputs, prime, polys, &error),
              "expand take pattern", error);

  require(polys.size() == 3, "expanded take-pattern polynomial count");

  SparsePolynomial expected0 = make_poly(prime, {{5, {2, 1}}});
  SparsePolynomial expected1 = make_poly(prime, {
      {5, {0, 0}},
      {7, {3, 0}}
    });
  SparsePolynomial expected2 = make_poly(prime, {{23, {0, 2}}});

  require(same_polynomial(polys[0], expected0, prime),
          "first expanded take-pattern polynomial");
  require(same_polynomial(polys[1], expected1, prime),
          "second expanded take-pattern polynomial");
  require(same_polynomial(polys[2], expected2, prime),
          "third expanded take-pattern polynomial");
}

void test_take_pattern_from_flat()
{
  PolyTakePattern pattern;
  std::string error;
  require_ret(make_poly_take_pattern_from_flat(
                2,
                {1, 2},
                {0, 0, 1, 2, 0, 1},
                {2, 1, 0, 0, 3, 0},
                pattern,
                &error),
              "make take pattern from flat arrays", error);

  require(pattern.size() == 2, "flat take-pattern polynomial count");
  require(pattern[0].size() == 1, "flat first polynomial term count");
  require(pattern[1].size() == 2, "flat second polynomial term count");
  require(pattern[0][0].input_node == 0 &&
          pattern[0][0].output_index == 0 &&
          same_monomial(pattern[0][0].monomial, PolyMonomial({2, 1})),
          "flat first take-pattern term");
}

void test_take_pattern_collects_zeroes()
{
  const UInt prime = BIG_UINT_PRIMES[0];
  PolyTakePattern pattern = {
    {
      PolyTakeTerm{0, 0, PolyMonomial({1, 0})},
      PolyTakeTerm{0, 1, PolyMonomial({1, 0})}
    }
  };
  std::vector<std::vector<UInt>> inputs = {
    {prime - 1, 1}
  };
  std::vector<SparsePolynomial> polys;
  std::string error;
  require_ret(expand_poly_take_pattern(pattern, inputs, prime, polys, &error),
              "expand cancelling take pattern", error);
  require(polys.size() == 1, "cancelling take-pattern polynomial count");
  require(polys[0].empty(), "cancelling take-pattern drops zero coefficient");
}

void test_take_pattern_validation_errors()
{
  PolyTakePattern bad = {
    {
      PolyTakeTerm{1, 0, PolyMonomial({1, 0})}
    }
  };
  std::string error;
  Ret ret = validate_poly_take_pattern(bad, {1}, 2, &error);
  require(ret == FAILED, "bad take-pattern validation fails");
  require(error.find("input node") != std::string::npos,
          "bad take-pattern error mentions input node");

  PolyTakePattern pattern;
  ret = make_poly_take_pattern_from_flat(0, {1}, {0, 0}, {}, pattern, &error);
  require(ret == FAILED, "zero-variable flat take-pattern fails");
  require(error.find("variable") != std::string::npos,
          "zero-variable flat take-pattern error mentions variable");
}

void test_learning_phase()
{
  const UInt prime = BIG_UINT_PRIMES[0];

  PolyTakePattern target_pattern = {
    {
      PolyTakeTerm{0, 0, PolyMonomial({3, 0})},
      PolyTakeTerm{0, 1, PolyMonomial({0, 1})}
    },
    {
      PolyTakeTerm{0, 2, PolyMonomial({2, 1})},
      PolyTakeTerm{0, 3, PolyMonomial({1, 0})}
    }
  };

  PolyTakePattern ideal_pattern = {
    {
      PolyTakeTerm{1, 0, PolyMonomial({2, 0})},
      PolyTakeTerm{1, 1, PolyMonomial({0, 1})}
    },
    {
      PolyTakeTerm{1, 2, PolyMonomial({1, 1})},
      PolyTakeTerm{1, 3, PolyMonomial({0, 0})}
    }
  };

  std::vector<std::vector<std::vector<UInt>>> slices = {
    {
      {1, 1, 1, 1},
      {1, 1, 1, 1}
    },
    {
      {1, 1, 1, 1},
      {1, 1, 1, 1}
    }
  };

  PolyReductionLearnOptions options;
  PolyReductionLearnResult result;
  require_ret(learn_poly_reduction_basis(prime, {"x", "y"},
                                         target_pattern, ideal_pattern,
                                         slices, options, result),
              "poly-reduction learning phase", result.error);

  require(result.prime == prime, "learning result kept active prime");
  require(result.basis.size() == 2, "learned monomial basis size");
  require(same_monomial(result.basis[0], PolyMonomial({0, 1})),
          "learned basis first monomial is y");
  require(same_monomial(result.basis[1], PolyMonomial({0, 0})),
          "learned basis second monomial is constant");
  require(result.output_size == 4, "learned output size is targets times basis");
  require(result.basis_by_slice.size() == 2, "learning stores basis per slice");
  require(result.normal_forms_by_slice.size() == 2,
          "learning stores normal forms per slice");
  require(result.traces.size() == 2, "learning stores msolve traces");
}

void test_learning_phase_inconsistent_basis()
{
  const UInt prime = BIG_UINT_PRIMES[0];

  PolyTakePattern target_pattern = {
    {
      PolyTakeTerm{0, 0, PolyMonomial({3, 0})},
      PolyTakeTerm{0, 1, PolyMonomial({0, 1})}
    }
  };

  PolyTakePattern ideal_pattern = {
    {
      PolyTakeTerm{1, 0, PolyMonomial({2, 0})},
      PolyTakeTerm{1, 1, PolyMonomial({0, 1})}
    },
    {
      PolyTakeTerm{1, 2, PolyMonomial({1, 1})},
      PolyTakeTerm{1, 3, PolyMonomial({0, 0})}
    }
  };

  std::vector<std::vector<std::vector<UInt>>> slices = {
    {
      {1, 1},
      {1, 1, 1, 1}
    },
    {
      {1, 0},
      {1, 1, 1, 1}
    }
  };

  PolyReductionLearnOptions options;
  PolyReductionLearnResult result;
  Ret ret = learn_poly_reduction_basis(prime, {"x", "y"},
                                       target_pattern, ideal_pattern,
                                       slices, options, result);
  require(ret == FAILED, "strict learning rejects inconsistent basis");
  require(result.error.find("inconsistent") != std::string::npos,
          "inconsistent learning error is clear");

  options.require_consistent_basis = false;
  require_ret(learn_poly_reduction_basis(prime, {"x", "y"},
                                         target_pattern, ideal_pattern,
                                         slices, options, result),
              "non-strict learning accepts union basis", result.error);
  require(result.basis.size() == 2, "non-strict learning returns union basis");
  require(same_monomial(result.basis[0], PolyMonomial({0, 1})),
          "union basis first monomial is y");
  require(same_monomial(result.basis[1], PolyMonomial({0, 0})),
          "union basis second monomial is constant");
  require(result.output_size == 2, "union learning output size");
}

void test_missing_msolve_error()
{
  MsolveOptions options;
  options.executable = "/definitely/not/a/finiteflow32/msolve";
  MsolveResult result;

  Ret ret = msolve_normal_forms_text(
    BIG_UINT_PRIMES[0], {"x"}, {"x+1"}, {"x^2"}, options, result);

  require(ret == FAILED, "missing msolve returns failure");
  require(result.error.find("executable") != std::string::npos,
          "missing msolve error is clear");
}

} // namespace

int main()
{
#if !FFLOW_USE_UINT32_PRIMES
  std::cerr << "FFLOW_USE_UINT32_PRIMES is not enabled.\n";
  return 1;
#endif

  test_split_msolve_output();
  test_missing_msolve_error();
  test_msolve_text_prototype();
  test_polynomial_representation();
  test_grevlex_order();
  test_msolve_parser();
  test_msolve_polynomial_prototype();
  test_take_pattern_expansion();
  test_take_pattern_from_flat();
  test_take_pattern_collects_zeroes();
  test_take_pattern_validation_errors();
  test_learning_phase();
  test_learning_phase_inconsistent_basis();

  std::cout << "finiteflow32 poly reduction stage 5 test passed\n";
  return 0;
}
