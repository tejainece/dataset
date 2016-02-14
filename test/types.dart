import 'package:test/test.dart';
import 'package:dataset/dataset.dart';
import 'package:quiver/iterables.dart' show enumerate;
import 'package:intl/intl.dart' show DateFormat;

typesTest() {
  var numbers = ['123', '0.34', '.23'];
  var not_numbers = [null, double.NAN];

  group("Dataset Numeric Type", () {
    /*test("Check number type", () {
      var notNumbers = ['a', {}, 'll22'];

      numbers.forEach((num) {
        expect(typeOf(num), equals("number"), reason: "Value should be number");
        expect(types['number'].test(num), isTrue,
            reason: "Should return true for a number");
      });

      notNumbers.forEach((nn) {
        expect(typeOf(nn), isNot(equals("number")),
            reason: "Value should not be number " + nn);
        expect(types['number'].test(nn), isFalse,
            reason: "Should not return true for a number " + nn);
      });
    });*/

    test("Check all non numeric values return null on numeric", () {
      types.values.forEach((type) {
        // not checking undefined - we either coerrced it out and can't
        // computationally derive it like a NaN
        expect(type.numeric(null), isNull,
            reason: "[${type.name}] null is represented "
                "as ${type.numeric(null)}");

        if (type == types['mixed'] || type == types['number']) {
          expect(type.numeric(double.NAN), isNull,
              reason: "[${type.name}] $double.NAN is represented "
                  "as ${type.numeric(double.NAN)}");
        }
      });
    });

    test("Check all non numeric values return null on coerce", () {
      types.values.forEach((type) {
        not_numbers.forEach((not_a_number) {
          expect(type.coerce(not_a_number), isNull,
              reason: "[${type.name}] $not_a_number  is represented "
                  "as ${type.coerce(not_a_number)}");
        });
      });
    });

    test("Coerce number type", () {
      var coerced = [123, 0.34, 0.23];
      enumerate(numbers).forEach((iv) {
        expect(types['number'].coerce(iv.value), equals(coerced[iv.index]),
            reason: "Should return true for a number");
      });
    });

    test("Coerce to null", () {
      var coerced = ['foo', null, double.NAN, {}];
      enumerate(coerced).forEach((iv) {
        expect(types['number'].coerce(coerced[iv.index]), isNull,
            reason: "Should return null for invalid input");
      });
    });

    test("Compare number type", () {
      expect(types['number'].compare(10, 20), equals(-1));
      expect(types['number'].compare(20, 10), equals(1));
      expect(types['number'].compare(10, 10), equals(0));
      expect(types['number'].compare(20, 200), equals(-1));
      expect(types['number'].compare(0, 0), equals(0));
      expect(types['number'].compare(-30, -40), equals(1));
      expect(types['number'].compare(-30, 0), equals(-1));
    });
  });

  /*group("Dataset Boolean Type", () {
    var booleans = ['true', 'false', true];

    test("Check boolean type", () {
      var notBooleans = [1, 'foo', {}];
      booleans.forEach((bool) {
        expect(typeOf(bool), equals("boolean"),
            reason: "Value should be boolean");
        expect(types['boolean'].test(bool), isTrue,
            reason: "Should return true for a bool");
      });
      notBooleans.forEach((nb) {
        expect(typeOf(nb), isNot(equals("boolean")),
            reason: "$nb Value should not be number");
        expect(types['boolean'].test(nb), isFalse,
            reason: "$nb Should not return true for a boolean");
      });
    });

    test("Coerce boolean type", () {
      var coerced = [true, false, true];
      enumerate(booleans).forEach((iv) {
        expect(types['boolean'].coerce(iv.value), equals(coerced[iv.index]),
            reason: "Should return true for a boolean");
      });
    });

    test("Compare boolean type", () {
      var results = [0, -1];
      enumerate([true, false]).forEach((iv) {
        expect(
            types['boolean'].compare(iv.value, true), equals(results[iv.index]),
            reason: "Should return true for a boolean");
      });
    });

    test("Numeric conversion", () {
      expect(types['boolean'].numeric(true), equals(1),
          reason: "True returns 1");
      expect(types['boolean'].numeric(false), equals(0),
          reason: "False returns 0");
    });

    test("Check weird types", () {
      expect(types['string'].compare(null, "a"), equals(-1));
      expect(types['string'].compare("a", null), equals(1));
      expect(types['string'].compare(null, null), equals(0));
//      expect(types['string'].compare(null, undefined), equals(0));
//      expect(types['string'].compare(undefined, undefined), equals(0));
//      expect(types['string'].compare(undefined, null), equals(0));

      expect(types['number'].compare(null, 1), equals(-1));
      expect(types['number'].compare(null, 0), equals(-1));
      expect(types['number'].compare(1, null), equals(1));
      expect(types['number'].compare(0, null), equals(1));
      expect(types['number'].compare(null, null), equals(0));
//      expect(types['number'].compare(null, undefined), equals(0));
//      expect(types['number'].compare(undefined, undefined), equals(0));
//      expect(types['number'].compare(undefined, null), equals(0));

      expect(types['boolean'].compare(null, true), equals(-1));
      expect(types['boolean'].compare(true, null), equals(1));
      expect(types['boolean'].compare(null, null), equals(0));
//      expect(types['boolean'].compare(null, undefined), equals(0));
//      expect(types['boolean'].compare(undefined, undefined), equals(0));
//      expect(types['boolean'].compare(undefined, null), equals(0));

      expect(types['time'].compare(null, new DateTime.now()), equals(-1));
      expect(types['time'].compare(new DateTime.now(), null), equals(1));
      expect(types['time'].compare(null, null), equals(0));
//      expect(types['time'].compare(null, undefined), equals(0));
//      expect(types['time'].compare(undefined, undefined), equals(0));
//      expect(types['time'].compare(undefined, null), equals(0));
    });
  });
  group("Dataset Time Type", () {
    test("Check date parsing formats", () {
      var testtimes = [
        {'input': "2011", 'format': "YYYY"},
        {'input': "11", 'format': "YY"},
        {'input': "2011/03", 'format': "YYYY/MM"},
        {'input': "2011/04/3", 'format': "YYYY/MM/D"},
        {'input': "2011/04/30", 'format': "YYYY/MM/D"},
        {'input': "2011/04/30", 'format': "YYYY/MM/D"},
        {'input': "20110430", 'format': "YYYYMMD"},
        {'input': "20110430", 'format': "YYYYMMDD"},
        {'input': "2011/4/03", 'format': "YYYY/M/DD"},
        {'input': "2011/4/30", 'format': "YYYY/M/DD"},
        {'input': "2011/6/2", 'format': "YYYY/M/D"},
        {'input': "2011/6/20", 'format': "YYYY/M/D"},
        {'input': "2011/6/20 4PM", 'format': "YYYY/M/D hA"},
        {'input': "2011/6/20 4PM", 'format': "YYYY/M/D hhA"},
        {'input': "2011/6/20 12PM", 'format': "YYYY/M/D hA"},
        {'input': "12PM", 'format': "hA"},
        {'input': "12:30 PM", 'format': "h:m A"},
        {'input': "5:05 PM", 'format': "h:m A"},
        {'input': "12:05 PM", 'format': "hh:mm A"},
        {'input': "-04:00", 'format': "Z"},
        {'input': "+04:00", 'format': "Z"},
        {'input': "-0400", 'format': "ZZ"},
        {'input': "+0400", 'format': "ZZ"},
        {'input': "AM -04:00", 'format': "A Z"},
        {'input': "PM +04:00", 'format': "A Z"},
        {'input': "AM -0400", 'format': "A ZZ"},
        {'input': "PM +0400", 'format': "A ZZ"},
        {'input': "12:05 -04:00", 'format': "hh:mm Z"},
        {'input': "12:05 +04:00", 'format': "hh:mm Z"},
        {'input': "12:05 -0400", 'format': "hh:mm ZZ"},
        {'input': "12:05 +0400", 'format': "hh:mm ZZ"},
        {'input': "12:05:30 +0400", 'format': "hh:mm:s ZZ"},
        {'input': "12:05:30 -0400", 'format': "hh:mm:ss ZZ"}
      ];
      testtimes.forEach((t) {
        expect(types['time'].test(t.input, {'format': t.format}), isTrue,
            reason: t.input);
        expect(types['time'].coerce(t.input, {'format': t.format}).valueOf(),
            isTrue,
            reason: moment(t.input, t.format).valueOf());
      });
    });

    test("Check date type", () {
      expect(types['time'].test("22/22/2001"), isTrue,
          reason: "date in correct format");
      expect(types['time'].test("20"), isFalse,
          reason: "date incorrect format");
    });

    test("Compare date type", () {
      var m = new DateTime(2011, 05, 01);
      var m2 = new DateTime(2011, 05, 05);
      var m3 = new DateTime(2011, 05, 01);

      expect(types['time'].compare(m, m2), equals(-1));
      expect(types['time'].compare(m2, m), equals(1));
      expect(types['time'].compare(m3, m), equals(0));
    });
  });

  group("Dataset String Type", () {
    test("Compare string type", () {
      expect(types['string'].compare("A", "B"), equals(-1));
      expect(types['string'].compare("C", "B"), equals(1));
      expect(types['string'].compare("bbb", "bbb"), equals(0));
      expect(types['string'].compare("bbb", "bbbb"), equals(-1));
      expect(types['string'].compare("bbb", "bbbb"), equals(-1));
      expect(types['string'].compare("bbbb", "bbb"), equals(1));
      expect(types['string'].compare("bbb", "bbb"), equals(0));
    });

    test("String type returns 0 or coerced form", () {
      expect(types['string'].numeric("A"), isNull);
      expect(types['string'].numeric(null), isNull);
      expect(types['string'].numeric("99"), equals(99));
      expect(types['string'].numeric("99.3"), equals(99.3));
    });
  });*/
}

main() => typesTest();
