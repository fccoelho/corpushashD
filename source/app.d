import std.stdio;
import std.range;
import std.digest.sha;
import std.base64;
import std.path: buildPath, isValidFilename;
import std.format;
import std.algorithm : fill;
import std.ascii : letters, digits;
import std.conv : to;
import std.random : randomCover, rndGen;
import std.range : chain;
import std.typecons: tuple, Tuple;
import std.file;

alias SHA256 = SHA256Digest;
alias dictionary = string[string];

alias document = string[];


class HashCorpus
{
    document[] corpus;
    string corpus_path;
    string encoding;
    int salt_length;
    dictionary encode_dictionary;
    dictionary decode_dictionary;
    string encode_dictionary_path;
    string decode_dictionary_path;

    this(document[] corpus,
        in string corpus_path,
        in string encoding="utf-8",
        in string hash_function="sha256",
        in int salt_length=32)
    {
    this.corpus = corpus;
    this.corpus_path = corpus_path;
    this.encoding = encoding;
    this.salt_length = salt_length;
    this.encode_dictionary_path = buildPath(this.corpus_path, "private/encode_dictionary.pkl");
    this.decode_dictionary_path = buildPath(this.corpus_path, "private/decode_dictionary.pkl");
    this.encode_dictionary, this.decode_dictionary = this._load_dictionaries();
    this.hash_corpus();

    }
    void hash_corpus()
    {
        uint ix = 0;
        foreach (i, doc; this.corpus)
        {
            document output_document = doc.dup; // copying here because the next method is recursive
            document encoded_document = this._hash_document(doc, output_document);
            auto encoded_document_path = buildPath(this.corpus_path, "public", format!"%s.json"(i,));
            this._export_work(encoded_document, encoded_document_path, false);
            ix += i;
        }
        this._export_work(this.encode_dictionary, this.encode_dictionary_path, true);
        this._export_work(this.decode_dictionary, this.decode_dictionary_path, true);
        writefln("%s documents hashed and saved to %s.", ix+1, buildPath(this.corpus_path, "public"));
    }

    auto _encode_token(string token)
    {
        string hashed_token;
        string salt;

        if (token in this.encode_dictionary)
        {
            return this.encode_dictionary[token];
        }
        else
        {
            res = hash_token(token, hash_function=this.hash_function, salt_length=this.salt_length);
            hashed_token = res[0];
            salt = res[1];

            while (hashed_token in this.decode_dictionary)
            {
                res = hash_token(token, hash_function=this.hash_function, salt_length=this.salt_length);
                hashed_token = res[0];
                salt = res[1];
            }
            this.decode_dictionary[hashed_token] = tuple(token, salt);
            this.encode_dictionary[token] = hashed_token;
        }
        return hashed_token;
    }

    auto _hash_document(T)(T input_document, document output_document)
    {
        foreach (ix, item ;input_document)
        {
            if (typeof(item) == string)
            {
                output_document[ix] = this._encode_token(item);
            }
            else
            {
                output_document[ix] = this._hash_document(item, output_document[ix]);
            }
        }

        return output_document;
    }

    auto _export_work(dictionary file_to_dump, string file_path, bool priv)
    {

    }

    auto _load_dictionaries()
    {
        if (isValidFilename(this.encode_dictionary_path) && isValidFilename(this.decode_dictionary_path))
        {

        }
    }
}

auto hash_token(string token, string hash_function, ubyte[] salt=null, uint salt_length=32)
{
    if (salt is null)
    {
        salt = get_salt(salt_length);
    }
    auto token_hasher = SHA256();
    ubyte[] token_digest = token_hasher.digest(token + salt);
    return tuple(toHexString(token_digest), salt);
}

auto get_salt(uint siz=32)
{
    auto asciiLetters = to!(dchar[])(letters);
    auto asciiDigits = to!(dchar[])(digits);
    dchar[siz] salt;
    fill(salt[], randomCover(chain(asciiLetters, asciiDigits), rndGen));
    return salt;
}

void main()
{
	writeln("Edit source/app.d to start your project.");
    writeln(get_salt(32));
}
