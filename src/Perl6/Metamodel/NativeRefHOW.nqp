#- Metamodel::NativeRefHOW -----------------------------------------------------
class Perl6::Metamodel::NativeRefHOW
    does Perl6::Metamodel::Naming
    does Perl6::Metamodel::Documenting
    does Perl6::Metamodel::Composing
    does Perl6::Metamodel::Versioning
    does Perl6::Metamodel::Stashing
    does Perl6::Metamodel::MultipleInheritance
    does Perl6::Metamodel::C3MRO
    does Perl6::Metamodel::MROBasedMethodDispatch
    does Perl6::Metamodel::MROBasedTypeChecking
{
    has     $!type;
    has     $!refkind;
    has int $!repr_composed;

    my $archetypes := Perl6::Metamodel::Archetypes.new(:nominal, :inheritable);
    method archetypes($XXX?) { $archetypes }

    method new(*%_) {
        nqp::findmethod(NQPMu, 'BUILDALL')(nqp::create(self), %_)
    }

    method new_type(:$name = '<anon>', :$ver, :$auth, :$api) {
        my $HOW    := self.new;
        my $target := nqp::settypehll(nqp::newtype($HOW, 'NativeRef'), 'Raku');

        $HOW.set_name($target, $name);
        $HOW.set_ver( $target, $ver);
        $HOW.set_auth($target, $auth) if $auth;
        $HOW.set_api( $target, $api)  if $api;
        $HOW.add_stash($target);
    }

    method compose($target, *%_) {
        $target := nqp::decont($target);

        self.compose_repr($target);
        self.compute_mro($target);
        self.publish_method_cache($target);
        self.publish_type_cache($target);
        self.set_composed;
        $target
    }

    method compose_repr($target) {
        unless $!repr_composed {
            nqp::composetype(nqp::decont($target), nqp::hash(
              'nativeref', nqp::hash(
                'type',    nqp::decont($!type),
                'refkind', $!refkind // 'unknown'
              )
            ));
            $!repr_composed := 1;
        }
    }

    method set_native_type($XXX, $type   ) { $!type    := $type    }
    method set_ref_kind(   $XXX, $refkind) { $!refkind := $refkind }

    method native_type($XXX?) { $!type    }
    method ref_kind($XXX?)    { $!refkind }

    method method_table($XXX?)    { nqp::hash }
    method submethod_table($XXX?) { nqp::hash }
}

# vim: expandtab sw=4
