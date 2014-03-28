/*
 * PEG.js Grammar
 * ==============
 *
 * PEG.js grammar syntax is designed to be simple, expressive, and similar to
 * JavaScript where possible. This means that many rules, especially in the
 * lexical part, are based on the grammar from ECMA-262, 5.1 Edition [1]. Some
 * are directly taken or adapted from the JavaScript example grammar (see
 * examples/javascript.pegjs).
 *
 * [1] http://www.ecma-international.org/publications/standards/Ecma-262.htm
 */

{
  function extractOptional(optional, index) {
    return optional ? optional[index] : null;
  }

  function extractList(list, index) {
    var result = new Array(list.length), i;

    for (i = 0; i < list.length; i++) {
      result[i] = list[i][index];
    }

    return result;
  }

  function buildList(first, rest, index) {
    return [first].concat(extractList(rest, index));
  }
}

Grammar
  = __ initializer:(Initializer __)? rules:(Rule __)+ {
      return {
        type:        "grammar",
        initializer: extractOptional(initializer, 0),
        rules:       extractList(rules, 0)
      };
    }

Initializer
  = code:Action (__ ";")? {
      return {
        type: "initializer",
        code: code
      };
    }

Rule
  = name:Identifier __
    displayName:(String __)?
    "=" __
    expression:Expression (__ ";")? {
      return {
        type:        "rule",
        name:        name,
        expression:  displayName !== null
          ? {
              type:       "named",
              name:       displayName[0],
              expression: expression
            }
          : expression
      };
    }

Expression
  = Choice

Choice
  = first:Sequence rest:(__ "/" __ Sequence)* {
      return rest.length > 0
        ? { type: "choice", alternatives: buildList(first, rest, 3) }
        : first;
    }

Sequence
  = first:Labeled rest:(__ Labeled)* __ code:Action {
      var expression = rest.length > 0
        ? { type: "sequence", elements: buildList(first, rest, 1) }
        : first;
      return {
        type:       "action",
        expression: expression,
        code:       code
      };
    }
  / first:Labeled rest:(__ Labeled)* {
      return rest.length > 0
        ? { type: "sequence", elements: buildList(first, rest, 1) }
        : first;
    }

Labeled
  = label:Identifier __ ":" __ expression:Prefixed {
      return {
        type:       "labeled",
        label:      label,
        expression: expression
      };
    }
  / Prefixed

Prefixed
  = "$" __ expression:Suffixed {
      return {
        type:       "text",
        expression: expression
      };
    }
  / "&" __ code:Action {
      return {
        type: "semantic_and",
        code: code
      };
    }
  / "&" __ expression:Suffixed {
      return {
        type:       "simple_and",
        expression: expression
      };
    }
  / "!" __ code:Action {
      return {
        type: "semantic_not",
        code: code
      };
    }
  / "!" __ expression:Suffixed {
      return {
        type:       "simple_not",
        expression: expression
      };
    }
  / Suffixed

Suffixed
  = expression:Primary __ "?" {
      return {
        type:       "optional",
        expression: expression
      };
    }
  / expression:Primary __ "*" {
      return {
        type:       "zero_or_more",
        expression: expression
      };
    }
  / expression:Primary __ "+" {
      return {
        type:       "one_or_more",
        expression: expression
      };
    }
  / Primary

Primary
  = name:Identifier !(__ (String __)? "=") {
      return {
        type: "rule_ref",
        name: name
      };
    }
  / Literal
  / Class
  / "." { return { type: "any" }; }
  / "(" __ expression:Expression __ ")" { return expression; }

/* "Lexical" elements */

Action "action"
  = braced:Braced __ { return braced.substr(1, braced.length - 2); }

Braced
  = $("{" (Braced / NonBraceCharacters)* "}")

NonBraceCharacters
  = NonBraceCharacter+

NonBraceCharacter
  = [^{}]

Identifier "identifier"
  = $((Letter / "_") (Letter / Digit / "_")*)

Literal "literal"
  = value:(DoubleQuotedString / SingleQuotedString) flags:"i"? {
      return {
        type:       "literal",
        value:      value,
        ignoreCase: flags === "i"
      };
    }

String "string"
  = string:(DoubleQuotedString / SingleQuotedString) { return string; }

DoubleQuotedString
  = '"' chars:DoubleQuotedCharacter* '"' { return chars.join(""); }

DoubleQuotedCharacter
  = SimpleDoubleQuotedCharacter
  / SimpleEscapeSequence
  / ZeroEscapeSequence
  / HexEscapeSequence
  / UnicodeEscapeSequence
  / EOLEscapeSequence

SimpleDoubleQuotedCharacter
  = !('"' / "\\" / EOLChar) char_:. { return char_; }

SingleQuotedString
  = "'" chars:SingleQuotedCharacter* "'" { return chars.join(""); }

SingleQuotedCharacter
  = SimpleSingleQuotedCharacter
  / SimpleEscapeSequence
  / ZeroEscapeSequence
  / HexEscapeSequence
  / UnicodeEscapeSequence
  / EOLEscapeSequence

SimpleSingleQuotedCharacter
  = !("'" / "\\" / EOLChar) char_:. { return char_; }

Class "character class"
  = "[" inverted:"^"? parts:(ClassCharacterRange / ClassCharacter)* "]" flags:"i"? {
      return {
        type:       "class",
        parts:      parts,
        rawText:    text().replace(/\s+$/, ""),
        inverted:   inverted === "^",
        ignoreCase: flags === "i"
      };
    }

ClassCharacterRange
  = begin:ClassCharacter "-" end:ClassCharacter {
      if (begin.charCodeAt(0) > end.charCodeAt(0)) {
        error("Invalid character range: " + text() + ".");
      }

      return [begin, end];
    }

ClassCharacter
  = BracketDelimitedCharacter

BracketDelimitedCharacter
  = SimpleBracketDelimitedCharacter
  / SimpleEscapeSequence
  / ZeroEscapeSequence
  / HexEscapeSequence
  / UnicodeEscapeSequence
  / EOLEscapeSequence

SimpleBracketDelimitedCharacter
  = !("]" / "\\" / EOLChar) char_:. { return char_; }

SimpleEscapeSequence
  = "\\" !(Digit / "x" / "u" / EOLChar) char_:. {
      return char_
        .replace("b", "\b")
        .replace("f", "\f")
        .replace("n", "\n")
        .replace("r", "\r")
        .replace("t", "\t")
        .replace("v", "\x0B"); // IE does not recognize "\v".
    }

ZeroEscapeSequence
  = "\\0" !Digit { return "\x00"; }

HexEscapeSequence
  = "\\x" digits:$(HexDigit HexDigit) {
      return String.fromCharCode(parseInt(digits, 16));
    }

UnicodeEscapeSequence
  = "\\u" digits:$(HexDigit HexDigit HexDigit HexDigit) {
      return String.fromCharCode(parseInt(digits, 16));
    }

EOLEscapeSequence
  = "\\" eol:EOL { return ""; }

Digit
  = [0-9]

HexDigit
  = [0-9a-fA-F]

Letter
  = LowerCaseLetter
  / UpperCaseLetter

LowerCaseLetter
  = [a-z]

UpperCaseLetter
  = [A-Z]

__ = (Whitespace / EOL / Comment)*

Comment "comment"
  = SingleLineComment
  / MultiLineComment

SingleLineComment
  = "//" (!EOLChar .)*

MultiLineComment
  = "/*" (!"*/" .)* "*/"

EOL "end of line"
  = "\n"
  / "\r\n"
  / "\r"
  / "\u2028"
  / "\u2029"

EOLChar
  = [\n\r\u2028\u2029]

Whitespace "whitespace"
  = [ \t\v\f\u00A0\uFEFF\u1680\u180E\u2000-\u200A\u202F\u205F\u3000]
