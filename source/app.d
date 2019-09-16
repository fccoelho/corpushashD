import corpushash.hashers;
import std.stdio;

void main()
{
    document[] corp = [["asdahsk", "sdlfjsldj","çsldkfçk"],["sdjçlkj","sadjfl"],["sdfçls","oirgk", "sdkfj"]];
    HashCorpus H = new HashCorpus(corp, "test_corpus");
    writeln(get_salt(64));
}
