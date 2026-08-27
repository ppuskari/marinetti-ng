import unittest


class IncrementalChecksum:
    def __init__(self):
        self.total = 0
        self.pending = None

    def add(self, data):
        pos = 0

        if self.pending is not None:
            if len(data):
                self.total += (self.pending << 8) | data[0]
                self.pending = None
                pos = 1
            else:
                return

        while pos + 1 < len(data):
            self.total += (data[pos] << 8) | data[pos + 1]
            pos += 2

        if pos < len(data):
            self.pending = data[pos]

    def final(self):
        value = self.total

        if self.pending is not None:
            value += self.pending << 8

        while value >> 16:
            value = (value & 0xFFFF) + (value >> 16)

        return (~value) & 0xFFFF


def checksum(*parts):
    state = IncrementalChecksum()

    for part in parts:
        state.add(part)

    return state.final()


class TCPRXChecksumTests(unittest.TestCase):

    def test_even_split(self):
        data = bytes(range(1, 101))
        self.assertEqual(
            checksum(data),
            checksum(data[:40], data[40:])
        )

    def test_odd_split(self):
        data = bytes(range(1, 101))
        self.assertEqual(
            checksum(data),
            checksum(data[:17], data[17:])
        )

    def test_multiple_odd_splits(self):
        data = bytes(((i % 255) + 1) for i in range(1460))
        self.assertEqual(
            checksum(data),
            checksum(
                data[:17],
                data[17:528],
                data[528:1001],
                data[1001:]
            )
        )

    def test_ring_wrap_odd_first_span(self):
        payload = bytes(((i % 255) + 1) for i in range(1000))
        first = payload[:511]
        second = payload[511:]

        self.assertEqual(len(first), 511)
        self.assertEqual(len(second), 489)
        self.assertEqual(
            checksum(payload),
            checksum(first, second)
        )

    def test_zero_byte_is_checksum_legal(self):
        data = bytes([0x12,0x00,0x34,0x56,0x00,0x78])
        self.assertEqual(
            checksum(data),
            checksum(data[:1],data[1:4],data[4:])
        )

    def test_full_mss_arbitrary_splits(self):
        payload = bytes(((i * 37 + 11) & 0xFF) for i in range(1460))
        self.assertEqual(
            checksum(payload),
            checksum(
                payload[:511],
                payload[511:1024],
                payload[1024:]
            )
        )


if __name__ == "__main__":
    unittest.main()
