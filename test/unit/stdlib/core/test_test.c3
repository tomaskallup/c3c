module test::std::core::test @test;
import std::core::runtime @public;
import std::core::builtin;
import std::io;

struct TestState
{
	int n_runs;
	int n_fails;
	bool expected_fail;

	// NOTE: we must wrap setup/teardown functions to hide them from module @test runner
	TestFn setup_fn;
	TestFn teardown_fn;
	PanicFn old_panic;  // original test panic, use it when it's really fails
	PanicFn panic_mock_fn; // mock panic, for testing the test:: failed
}

TestState state =
{
	.setup_fn = fn void()
	{
		state.n_runs++;
		state.n_fails = 0;

		assert (runtime::test_context.assert_print_backtrace);
		assert (builtin::panic != state.panic_mock_fn, "missing finalization of panic");

		state.old_panic = builtin::panic;
		builtin::panic = state.panic_mock_fn;
	},
	.teardown_fn = fn void()
	{
		builtin::panic = state.old_panic;

		assert(state.n_runs > 0);

		if (state.expected_fail)
		{
			assert(state.n_fails > 0, "test case expected to fail, but it's not");
		}
		state.n_fails = 0;
		state.expected_fail = false;
		state.n_runs = 0;
	},
	.panic_mock_fn = fn void (String message, String file, String function, uint line)
	{
		if (runtime::test_context.is_in_panic) return;
		if (runtime::test_context.assert_print_backtrace)
		{
			$if env::NATIVE_STACKTRACE:
				builtin::print_backtrace(message, 0);
			$else 
				io::printfn("No print_backtrace() supported by this platform");
			$endif
		}
		runtime::test_context.assert_print_backtrace = true;
		if (state.expected_fail)
		{
			state.n_fails++;
		}
		else
		{
			builtin::panic = state.old_panic;
			state.old_panic(message, file, function, line);
		}
		runtime::test_context.is_in_panic = false;
	}
};


fn void test_eq()
{
	test::is_equal(1, 1);
	test::is_equal(true, true);
	test::is_equal(1.31, 1.31);
	test::is_equal("foo", "foo");
}

fn void test_almost_equal()
{
	test::is_almost_equal(1, 1);
	test::is_almost_equal(1.31, 1.31);
	test::is_almost_equal(1.31f, 1.31f);
	test::is_almost_equal(double.nan, double.nan);
	test::is_almost_equal(float.nan, float.nan);
	test::is_almost_equal(1.31, 1.31, delta: 0.01);
	test::is_almost_equal(1.311, 1.312, delta: 0.01);
	test::is_almost_equal(1.311, 1.312, places: 2);
	// 7 decimal places are default
	test::is_almost_equal(1.00000001, 1.00000000);
}


fn void test_almost_equal_fails()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	// 7 decimal places are default
	test::is_almost_equal(1.0000001, 1.00000000);
}

fn void test_almost_equal_fails_nan()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_almost_equal(1.0000001, double.nan);
}

fn void test_almost_equal_fails_nan2()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_almost_equal(double.nan, 1);
}

fn void test_almost_equal_fails_equal_nan_false()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_almost_equal(double.nan, double.nan, equal_nan: false);
}

fn void setup_teardown()
{
	state.n_runs = 0; // just in case of previous test failed
	test::setup(state.setup_fn, state.teardown_fn);

	test::is_equal(state.n_runs, 1);
	test::is_equal(state.n_fails, 0);
	test::is_equal(state.expected_fail, false);
}

fn void setup_no_teardown()
{
	test::setup(state.setup_fn);

	test::is_equal(state.n_runs, 1);
	test::is_equal(state.n_fails, 0);
	test::is_equal(state.expected_fail, false);

	// WARNING: reverting back original panic func
	builtin::panic = state.old_panic;
}

fn void expected_fail()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_equal(state.n_fails, 0);
	test::is_equal(2, 1); // this fails, and we test it
	test::is_equal(state.n_fails, 1);
}

fn void test_neq()
{
	test::is_not_equal(2, 1);
	test::is_not_equal(false, true);
	test::is_not_equal(1.32, 1.31);
	test::is_not_equal("foo", "bar");
}

fn void test_neq_fails()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_not_equal(1, 1);
}

fn void test_gt()
{
	test::is_greater(2, 1);
	test::is_greater(true, false);
	test::is_greater(1.32, 1.31);
}

fn void test_gt_fails_when_equal()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_greater(2, 2);
}

fn void test_gt_fails_when_less()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_greater(1, 2);
}


fn void test_gte()
{
	test::is_greater_equal(2, 1);
	test::is_greater_equal(true, false);
	test::is_greater_equal(1.32, 1.31);
	test::is_greater_equal(2, 2);
	test::is_greater_equal(true, true);
	test::is_greater_equal(1.32, 1.32);
}

fn void test_gte_fails_when_less()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_greater_equal(1, 2);
}

fn void test_lt()
{
	test::is_less(1, 2);
	test::is_less(false, true);
	test::is_less(1.31, 1.32);
}

fn void test_lt_fails_when_equal()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_less(2, 2);
}

fn void test_lt_fails_when_greater()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_less(2, 1);
}

fn void test_lte()
{
	test::is_less_equal(1, 2);
	test::is_less_equal(false, true);
	test::is_less_equal(1.31, 1.32);
	test::is_less_equal(2, 2);
	test::is_less_equal(true, true);
	test::is_less_equal(1.32, 1.32);
}

fn void test_lte_fails_when_greater()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::is_less_equal(2, 1);
}

fn void test_check(){
	test::@check(1 == 1);
	test::@check(1.2 == 1.2, "1 == 1");
	test::@check(true == true, "1 == 1");
	test::@check("foo" == "foo", "2 == %d", 1 );
}

fn void test_check_fails()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::@check(2 == 1, "2 == %d", 1 );
}

fn void test_check_fails_no_info()
{
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::@check(2 == 1);
}

def TestIntFn = fn int! (int a, int b);
def TestFailFn = fn void! (bool to_fail);

fault MyFault
{
	FOO,
}

fn void test_error()
{
	TestFailFn ffail_void = fn void!(bool to_fail)
	{
		if (to_fail) return IoError.FILE_NOT_FOUND?;
	};
	TestIntFn ffail_int = fn int! (int a, int b)
	{
		if (b == 0) return IoError.FILE_NOT_FOUND?;
		return a / b;
	};
	test::setup(state.setup_fn, state.teardown_fn);

	test::@error(ffail_void(true), IoError.FILE_NOT_FOUND);
	test::@error(ffail_int(1, 0), IoError.FILE_NOT_FOUND);
}

fn void test_error_not_raised()
{
	TestIntFn ffail_int = fn int! (int a, int b) {
		if (b == 0) return IoError.FILE_NOT_FOUND?;
		return a / b;
	};
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;
	test::@error(ffail_int(1, 1), IoError.FILE_NOT_FOUND);
}

fn void test_error_wrong_error_expected()
{
	TestIntFn ffail_int = fn int! (int a, int b) {
		if (b == 0) return IoError.BUSY?;
		return a / b;
	};
	test::setup(state.setup_fn, state.teardown_fn);
	state.expected_fail = true;

	test::@error(ffail_int(1, 0), IoError.FILE_NOT_FOUND);
}

fn void test_std_out_hijack()
{
	io::print("print: aldsjalsdjlasjdlja\n");
	io::printf("printf: aldsjalsdjlasjdlja\n");
	io::eprint("eprint: aldsjalsdjlasjdlja\n");
	io::eprintfn("eprintfn: aldsjalsdjlasjdlja\n");
	io::fprint(io::stdout(), "fprint: stdout aldsjalsdjlasjdlja\n")!!;
	io::fprint(io::stderr(), "fprint: stderr aldsjalsdjlasjdlja\n")!!;
	io::fprintf(io::stderr(), "fprintf: stderr aldsjalsdjlasjdlja\n")!!;
	io::fprintf(io::stderr(), "fprintfn: stderr aldsjalsdjlasjdlja\n")!!;
	test::is_equal(true, true);
}
