unit module C101;

subset FullStr of Str  where *.chars > 0;
subset Salary  of Real where *       > 0;

our class Company    is export {...}
our class Department is export {...}
our class Employee   is export {...}


class Unit
{
    has FullStr $.name is rw;

    method total  { $.salary }
    method median { $.salary / $.count }
    method cut    { self.visit: { .salary /= 2 when Employee } }

    method unparse   { $.gist }
    method serialize { $.perl }

    method visit(Callable:D $visitor)
    {
        $visitor(self);
        @.children».visit($visitor);
    }
}

class Subunit is Unit {}


sub qu($text) { $text ~~ /\s/ ?? qq/"$text"/ !! $text }

role Parent
{
    has Subunit @.children;

    method salary { [+] @.children».salary }
    method count  { [+] @.children».count  }

    method gist
    {
        my $subunits = @.children».gist.join("\n").indent(4);
        return "{self.^name} {qu $.name} (\n$subunits\n)";
    }
}

class Company    is Unit    does Parent {}
class Department is Subunit does Parent {}
class Employee   is Subunit
{
    has FullStr $.address is rw;
    has Salary  $.salary  is rw;

    method children {}
    method count    { 1 }
    method gist     { join ' ', self.^name, map { .&qu }, $.name, $.address, $.salary }

}


grammar UnitGrammar
{
    rule TOP { <ws>? [<company>|<department>|<employee>] <ws>? }

    rule company    { 'Company'    <identifier> '(' <department>* ')' }
    rule department { 'Department' <identifier> '('      <child>* ')' }
    rule employee   { 'Employee'   <identifier> ** 3 }

    rule child { <department>|<employee> }

    token identifier { '"' $<text> = .+? '"' || $<text> = \S+ }
}

class UnitActions
{
    method TOP($/) { $/.make: first ?*, $/<company department employee>».made }

    method company($/)
    {
        $/.make: Company.new:
            :name(~$/<identifier>.made),
            :children($/<department>».made),
    }

    method department($/)
    {
        $/.make: Department.new:
            :name(~$/<identifier>.made),
            :children($/<child>».made),
    }

    method employee($/)
    {
        $/.make: Employee.new:
            :name(   ~$/<identifier>[0].made),
            :address(~$/<identifier>[1].made),
            :salary( +$/<identifier>[2].made),
    }

    method child($/) { $/.make: first ?*, $/<department employee>».made }

    method identifier($/) { $/.make: $/<text> }
}

our sub parse($text)
{
    my $match = UnitGrammar.parse(~$text, :actions(UnitActions))
        or fail "Can't parse '$text'";
    return $match.made;
}

our sub deserialize($text) { EVAL $text }
