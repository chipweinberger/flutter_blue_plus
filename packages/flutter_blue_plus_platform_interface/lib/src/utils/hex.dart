// Copyright 2015, the Dart project authors.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
// * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following
// disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of Google LLC nor the names of its
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// coverage:ignore-file

import 'dart:convert';
import 'dart:typed_data';

/// The canonical instance of [HexCodec].
const hex = HexCodec._();

/// A codec that converts byte arrays to and from hexadecimal strings, following
/// [the Base16 spec](https://tools.ietf.org/html/rfc4648#section-8).
///
/// This should be used via the [hex] field.
class HexCodec extends Codec<List<int>, String> {
  const HexCodec._();

  @override
  HexEncoder get encoder {
    return const HexEncoder._();
  }

  @override
  HexDecoder get decoder {
    return const HexDecoder._();
  }
}

/// A converter that encodes byte arrays into hexadecimal strings.
///
/// This will throw a [RangeError] if the byte array has any digits that don't
/// fit in the gamut of a byte.
class HexEncoder extends Converter<List<int>, String> {
  const HexEncoder._();

  @override
  String convert(List<int> input) {
    return _convert(input, 0, input.length);
  }

  @override
  ByteConversionSink startChunkedConversion(Sink<String> sink) {
    return _HexEncoderSink(sink);
  }
}

/// A conversion sink for chunked hexadecimal encoding.
class _HexEncoderSink extends ByteConversionSinkBase {
  /// The underlying sink to which decoded byte arrays will be passed.
  final Sink<String> _sink;

  _HexEncoderSink(this._sink);

  @override
  void add(List<int> chunk) {
    _sink.add(_convert(chunk, 0, chunk.length));
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    RangeError.checkValidRange(start, end, chunk.length);
    _sink.add(_convert(chunk, start, end));
    if (isLast) _sink.close();
  }

  @override
  void close() {
    _sink.close();
  }
}

String _convert(List<int> bytes, int start, int end) {
  // A Uint8List is more efficient than a StringBuffer given that we know that
  // we're only emitting ASCII-compatible characters, and that we know the
  // length ahead of time.
  var buffer = Uint8List((end - start) * 2);
  var bufferIndex = 0;

  // A bitwise OR of all bytes in [bytes]. This allows us to check for
  // out-of-range bytes without adding more branches than necessary to the
  // core loop.
  var byteOr = 0;
  for (var i = start; i < end; i++) {
    var byte = bytes[i];
    byteOr |= byte;

    // The bitwise arithmetic here is equivalent to `byte ~/ 16` and `byte % 16`
    // for valid byte values, but is easier for dart2js to optimize given that
    // it can't prove that [byte] will always be positive.
    buffer[bufferIndex++] = _codeUnitForDigit((byte & 0xF0) >> 4);
    buffer[bufferIndex++] = _codeUnitForDigit(byte & 0x0F);
  }

  if (byteOr >= 0 && byteOr <= 255) return String.fromCharCodes(buffer);

  // If there was an invalid byte, find it and throw an exception.
  for (var i = start; i < end; i++) {
    var byte = bytes[i];
    if (byte >= 0 && byte <= 0xff) continue;
    throw FormatException(
      "Invalid byte ${byte < 0 ? "-" : ""}0x${byte.abs().toRadixString(16)}.",
      bytes,
      i,
    );
  }

  throw StateError('unreachable');
}

/// Returns the ASCII/Unicode code unit corresponding to the hexadecimal digit
/// [digit].
int _codeUnitForDigit(int digit) {
  return digit < 10 ? digit + 0x30 : digit + 0x61 - 10;
}

/// A converter that decodes hexadecimal strings into byte arrays.
///
/// Because two hexadecimal digits correspond to a single byte, this will throw
/// a [FormatException] if given an odd-length string. It will also throw a
/// [FormatException] if given a string containing non-hexadecimal code units.
class HexDecoder extends Converter<String, List<int>> {
  const HexDecoder._();

  @override
  Uint8List convert(String input) {
    if (!input.length.isEven) {
      throw FormatException(
        'Invalid input length, must be even.',
        input,
        input.length,
      );
    }

    var bytes = Uint8List(input.length ~/ 2);
    _decode(input.codeUnits, 0, input.length, bytes, 0);
    return bytes;
  }

  @override
  StringConversionSink startChunkedConversion(Sink<List<int>> sink) {
    return _HexDecoderSink(sink);
  }
}

/// A conversion sink for chunked hexadecimal decoding.
class _HexDecoderSink extends StringConversionSinkBase {
  /// The underlying sink to which decoded byte arrays will be passed.
  final Sink<List<int>> _sink;

  /// The trailing digit from the previous string.
  ///
  /// This will be non-`null` if the most recent string had an odd number of
  /// hexadecimal digits. Since it's the most significant digit, it's always a
  /// multiple of 16.
  int? _lastDigit;

  _HexDecoderSink(this._sink);

  @override
  void addSlice(String string, int start, int end, bool isLast) {
    RangeError.checkValidRange(start, end, string.length);

    if (start == end) {
      if (isLast) _close(string, end);
      return;
    }

    var codeUnits = string.codeUnits;
    Uint8List bytes;
    int bytesStart;
    if (_lastDigit == null) {
      bytes = Uint8List((end - start) ~/ 2);
      bytesStart = 0;
    } else {
      var hexPairs = (end - start - 1) ~/ 2;
      bytes = Uint8List(1 + hexPairs);
      bytes[0] = _lastDigit! + _digitForCodeUnit(codeUnits, start);
      start++;
      bytesStart = 1;
    }

    _lastDigit = _decode(codeUnits, start, end, bytes, bytesStart);

    _sink.add(bytes);
    if (isLast) _close(string, end);
  }

  @override
  ByteConversionSink asUtf8Sink(bool allowMalformed) {
    return _HexDecoderByteSink(_sink);
  }

  @override
  void close() => _close();

  /// Like [close], but includes [string] and [index] in the [FormatException]
  /// if one is thrown.
  void _close([String? string, int? index]) {
    if (_lastDigit != null) {
      throw FormatException(
        'Input ended with incomplete encoded byte.',
        string,
        index,
      );
    }

    _sink.close();
  }
}

/// A conversion sink for chunked hexadecimal decoding from UTF-8 bytes.
class _HexDecoderByteSink extends ByteConversionSinkBase {
  /// The underlying sink to which decoded byte arrays will be passed.
  final Sink<List<int>> _sink;

  /// The trailing digit from the previous string.
  ///
  /// This will be non-`null` if the most recent string had an odd number of
  /// hexadecimal digits. Since it's the most significant digit, it's always a
  /// multiple of 16.
  int? _lastDigit;

  _HexDecoderByteSink(this._sink);

  @override
  void add(List<int> chunk) {
    addSlice(chunk, 0, chunk.length, false);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    RangeError.checkValidRange(start, end, chunk.length);

    if (start == end) {
      if (isLast) _close(chunk, end);
      return;
    }

    Uint8List bytes;
    int bytesStart;
    if (_lastDigit == null) {
      bytes = Uint8List((end - start) ~/ 2);
      bytesStart = 0;
    } else {
      var hexPairs = (end - start - 1) ~/ 2;
      bytes = Uint8List(1 + hexPairs);
      bytes[0] = _lastDigit! + _digitForCodeUnit(chunk, start);
      start++;
      bytesStart = 1;
    }

    _lastDigit = _decode(chunk, start, end, bytes, bytesStart);

    _sink.add(bytes);
    if (isLast) _close(chunk, end);
  }

  @override
  void close() {
    _close();
  }

  /// Like [close], but includes [chunk] and [index] in the [FormatException]
  /// if one is thrown.
  void _close([List<int>? chunk, int? index]) {
    if (_lastDigit != null) {
      throw FormatException(
        'Input ended with incomplete encoded byte.',
        chunk,
        index,
      );
    }

    _sink.close();
  }
}

/// Decodes [codeUnits] and writes the result into [destination].
///
/// This reads from [codeUnits] between [sourceStart] and [sourceEnd]. It writes
/// the result into [destination] starting at [destinationStart].
///
/// If there's a leftover digit at the end of the decoding, this returns that
/// digit. Otherwise it returns `null`.
int? _decode(
  List<int> codeUnits,
  int sourceStart,
  int sourceEnd,
  List<int> destination,
  int destinationStart,
) {
  var destinationIndex = destinationStart;
  for (var i = sourceStart; i < sourceEnd - 1; i += 2) {
    var firstDigit = _digitForCodeUnit(codeUnits, i);
    var secondDigit = _digitForCodeUnit(codeUnits, i + 1);
    destination[destinationIndex++] = 16 * firstDigit + secondDigit;
  }

  if ((sourceEnd - sourceStart).isEven) return null;
  return 16 * _digitForCodeUnit(codeUnits, sourceEnd - 1);
}

/// Returns the digit (0 through 15) corresponding to the hexadecimal code unit
/// at index [index] in [codeUnits].
///
/// If the given code unit isn't valid hexadecimal, throws a [FormatException].
int _digitForCodeUnit(
  List<int> codeUnits,
  int index,
) {
  // If the code unit is a numeral, get its value. XOR works because 0 in ASCII
  // is `0b110000` and the other numerals come after it in ascending order and
  // take up at most four bits.
  //
  // We check for digits first because it ensures there's only a single branch
  // for 10 out of 16 of the expected cases. We don't count the `digit >= 0`
  // check because branch prediction will always work on it for valid data.
  var codeUnit = codeUnits[index];
  var digit = 0x30 ^ codeUnit;
  if (digit <= 9) {
    if (digit >= 0) return digit;
  } else {
    // If the code unit is an uppercase letter, convert it to lowercase. This
    // works because uppercase letters in ASCII are exactly `0b100000 = 0x20`
    // less than lowercase letters, so if we ensure that that bit is 1 we ensure
    // that the letter is lowercase.
    var letter = 0x20 | codeUnit;
    if (0x61 <= letter && letter <= 0x66) return letter - 0x61 + 10;
  }

  throw FormatException(
    'Invalid hexadecimal code unit '
    "U+${codeUnit.toRadixString(16).padLeft(4, '0')}.",
    codeUnits,
    index,
  );
}
