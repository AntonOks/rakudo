my role IO::Socket {
    has $!PIO;
    has Str $.encoding = 'utf8';
    has $.nl-in is rw = ["\n", "\r\n"];
    has Str:D $.nl-out is rw = "\n";
    has Encoding::Decoder $!decoder;
    has Encoding::Encoder $!encoder;

    method !ensure-decoder(--> Nil) {
        unless $!decoder.DEFINITE {
            my $encoding = Encoding::Registry.find($!encoding);
            $!decoder := $encoding.decoder();
            $!decoder.set-line-separators($!nl-in.list);
        }
    }

    method !ensure-encoder(--> Nil) {
        unless $!encoder.DEFINITE {
            my $encoding = Encoding::Registry.find($!encoding);
            $!encoder := $encoding.encoder();
        }
    }

    method !pull-bytes(Int $limit) {
        if $!decoder.DEFINITE {
            $!decoder.consume-exactly-bytes($limit)
                // nqp::readfh($!PIO, nqp::create(buf8.^pun), $limit)
        }
        else {
            nqp::readfh($!PIO, nqp::create(buf8.^pun), $limit)
        }
    }

    # The if bin is true, will return Buf, Str otherwise
    method recv(Cool $limit? is copy, :$bin) {
        fail('Socket not available') unless $!PIO;
        $limit = 65535 if !$limit.DEFINITE || $limit === Inf;
        if $bin {
            self!pull-bytes($limit)
        }
        else {
            self!ensure-decoder();
            my $result = $!decoder.consume-exactly-chars($limit);
            without $result {
                $!decoder.add-bytes(nqp::readfh($!PIO, nqp::create(buf8.^pun), 65535));
                $result = $!decoder.consume-exactly-chars($limit);
                without $result {
                    $result = $!decoder.consume-all-chars();
                }
            }
            $result
        }
    }

    method read(IO::Socket:D: Int(Cool) $bufsize) {
        fail('Socket not available') unless $!PIO;
        my int $toread = $bufsize;

        my $res := self!pull-bytes($toread);

        while nqp::elems($res) < $toread {
            my $buf := self!pull-bytes($toread - nqp::elems($res));
            nqp::elems($buf)
              ?? $res.append($buf)
              !! return $res
        }
        $res
    }

    method nl-in is rw {
        Proxy.new(
            FETCH => { $!nl-in },
            STORE => -> $, $nl-in {
                $!nl-in = $nl-in;
                with $!decoder {
                    .set-line-separators($!nl-in.list);
                }
                $nl-in
            }
        )
    }

    method get() {
        self!ensure-decoder();
        my Str $line = $!decoder.consume-line-chars(:chomp);
        if $line.DEFINITE {
            $line
        }
        else {
            loop {
                my $read = nqp::readfh($!PIO, nqp::create(buf8.^pun), 65535);
                $!decoder.add-bytes($read);
                $line = $!decoder.consume-line-chars(:chomp);
                last if $line.DEFINITE;
                if $read == 0 {
                    $line = $!decoder.consume-line-chars(:chomp, :eof)
                        unless $!decoder.is-empty;
                    last;
                }
            }
            $line.DEFINITE ?? $line !! Nil
        }
    }

    method lines() {
        gather while (my $line = self.get()).DEFINITE {
            take $line;
        }
    }

    method print(Str(Cool) $string --> True) {
        self!ensure-encoder();
        self.write($!encoder.encode-chars($string));
    }

    method put(Str(Cool) $string --> True) {
        self.print($string ~ $!nl-out);
    }

    method write(Blob:D $buf --> True) {
        fail('Socket not available') unless $!PIO;
        nqp::writefh($!PIO, nqp::decont($buf));
    }

    method close(--> True) {
        fail("Not connected!") unless $!PIO;
        nqp::closefh($!PIO);
        $!PIO := nqp::null;
    }

    method native-descriptor(::?CLASS:D:) {
        nqp::filenofh($!PIO)
    }
}

# vim: expandtab shiftwidth=4
