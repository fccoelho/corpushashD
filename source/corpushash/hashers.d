module corpushash.hashers;

import std.stdio;
import std.range;
import std.digest.sha;
import std.base64;
import std.path : buildPath, isValidFilename;
import std.format;
import std.uni;
import std.conv : to;
import std.random : randomSample;
import std.range : chain;
import std.typecons : tuple, Tuple;
import std.file;
import std.json;
import std.traits;
import std.datetime;
import pyd.pyd;

alias dictionary = dstring[string];
alias Ddictionary = dstring[2][string];
alias document = dstring[];

class HashCorpus
{
    document[] corpus;
    string corpus_path;
    string public_path;
    string encoding;
    uint salt_length;
    dictionary encode_dictionary;
    Ddictionary decode_dictionary;
    string encode_dictionary_path;
    string decode_dictionary_path;

    this(document[] corpus, string corpus_path, string encoding = "utf-32",
            const uint salt_length = 32)
    {
        this.corpus = corpus;
        this.corpus_path = corpus_path;
        this.public_path = this.setup_corpus_path();
        this.encoding = encoding;
        this.salt_length = salt_length;
        this.encode_dictionary_path = buildPath(this.corpus_path, "private",
                "encode_dictionary.json");
        this.decode_dictionary_path = buildPath(this.corpus_path, "private",
                "decode_dictionary.json");
        this._load_dictionaries();
        //this.encode_dictionary = dicts[0];
        //this.decode_dictionary = dicts[1];
        writeln(this.encode_dictionary);
        this.hash_corpus();

    }
    ///Sets up the output path
    string setup_corpus_path()
    {
        writefln("setting up output directory on: %s", this.corpus_path);
        auto currentTime = Clock.currTime();
        string timeString = currentTime.toISOString();
        string public_path = buildPath(this.corpus_path, "public", timeString);
        mkdirRecurse(public_path);
        string priv = buildPath(this.corpus_path, "private");
        if (!priv.exists)
        {
            mkdirRecurse(priv);
        }
        return public_path;
    }
    ///Hashes the corpus
    void hash_corpus()
    {
        uint ix = 0;
        foreach (i, doc; this.corpus)
        {
            document output_document = doc.dup; // copying here because the next method is recursive
            document encoded_document = this._hash_document(doc, output_document);
            auto encoded_document_path = buildPath(this.public_path, format!"%s.json"(i,));
            this._export_encoded_document(encoded_document, encoded_document_path);
            ix += i;
        }

        this._export_dictionary(this.encode_dictionary, this.encode_dictionary_path);
        this._export_Ddictionary(this.decode_dictionary, this.decode_dictionary_path);
        writefln("%s documents hashed and saved to %s.", ix + 1, this.public_path);

    }

    ///Encodes one token
    dstring _encode_token(dstring token)
    {
        string token_str;
        string hashed_token;
        dstring salt;

        token_str = to!string(token);

        if ((token_str in this.encode_dictionary) !is null)
        {
            writeln("using existing hash");
            return this.encode_dictionary[token_str];
        }
        else
        {
            auto res = hash_token(token);
            hashed_token = res[0];
            salt = res[1];

            while (hashed_token in this.decode_dictionary)
            {
                res = hash_token(token);
                hashed_token = res[0];
                salt = res[1];
            }
            this.decode_dictionary[hashed_token] = [token, salt];
            this.encode_dictionary[token_str] = to!dstring(hashed_token);
        }
        return to!dstring(hashed_token);
    }

    document _hash_document(document input_document, document output_document)
    {
        foreach (ix, item; input_document)
        {
            if (isSomeString!(typeof(item)))
            {
                output_document[ix] = to!dstring(this._encode_token(item));
            }
            else
            {
                throw new FileException("Document must be a list of strings");
            }
        }

        return output_document;
    }

    void _export_dictionary(dictionary file_to_dump, string file_path)
    {
        JSONValue payload = JSONValue(file_to_dump);
        File(file_path, "w").write(payload.toJSON);
    }

    void _export_Ddictionary(Ddictionary file_to_dump, string file_path)
    {
        JSONValue payload = JSONValue(file_to_dump);
        File(file_path, "w").write(payload.toJSON);
    }

    void _export_encoded_document(document doc_to_dump, string file_path)
    {
        JSONValue payload = JSONValue(doc_to_dump);
        File(file_path, "w").write(payload.toJSON);
    }

    /**
     * Load prevously saved dictionaries
     * 
     * <detailed description>
     *
     * Params:
     */
    void _load_dictionaries()
    {
        if (this.encode_dictionary_path.exists && this.decode_dictionary_path.exists)
        {
            writeln("Dictionaries from previous hashing found.\n Loading them.");
            JSONValue encode_dictionary = this.encode_dictionary_path.readText.parseJSON;
            JSONValue decode_dictionary = this.decode_dictionary_path.readText.parseJSON;
        }
        else
        {
            dictionary encode_dictionary;
            Ddictionary decode_dictionary;
        }
        writeln(encode_dictionary);
        this.encode_dictionary = encode_dictionary;
        this.decode_dictionary = decode_dictionary;
        // return [encode_dictionary, decode_dictionary;
    }
}

/**
* Hashes a string adding a random salt to it of specified size
* params:
*   token = string to be hashed
*   salt = Salt to add
*   salt_length = Length of the salt in bits
*/
Tuple!(string,dstring) hash_token(dstring token, dstring salt = null, uint salt_length = 32)
{
    if (salt is null)
    {
        salt = get_salt(salt_length);
    }
    auto token_hasher = new SHA256Digest();
    ubyte[] token_digest = token_hasher.digest(token ~ salt);
    return tuple(toHexString(token_digest), salt);
}
/**
*  Random salt generator
*  params:
*  siz = Length of the salt in bits
*/
dstring get_salt(uint siz)
{
    auto unicodechars = unicode("Cyrillic") | unicode("Armenian") | unicode("Telugu");
    dstring unichars = to!(dstring)(unicodechars.byCodepoint);

    return to!dstring(randomSample(unichars, siz));
}

/**
* Python wrapper
*/
extern (C) void PydMain()
{
    alias document = dstring[];
    module_init();
    def!(get_salt)();
    wrap_class!(HashCorpus,
            Property!(HashCorpus.corpus),
            Property!(HashCorpus.corpus_path),
            Property!(HashCorpus.encoding),
            Property!(HashCorpus.salt_length),
            Init!(document[], string, string, const uint),)();

}

/**
* Unittests
**/

/// Testing the hashing
unittest
{
    document[] corp = [["asdahsk", "sdlfjsldj","çsldkfçk"],["sdjçlkj","sadjfl"],["sdfçls","oirgk", "sdkfj"]];
    HashCorpus H = new HashCorpus(corp, "test_corpus");
    assert("asdahsk" in H.encode_dictionary);
}

/// Test the loading of dictionaries
unittest
{
    document[] corp = [
        ["asdahsk", "sdlfjsldj", "çsldkfçk"], ["sdjçlkj", "sadjfl"],
        ["sdfçls", "oirgk", "sdkfj"]
    ];
    HashCorpus H = new HashCorpus(corp, "test_corpus");
    // Make a copy of the dictionaries
    dictionary original_enc_dict = H.encode_dictionary;
    Ddictionary original_dec_dict = H.decode_dictionary;
    // Force the re-loading from disk again;
    H._load_dictionaries();
    foreach (word; [
            "asdahsk", "sdlfjsldj", "çsldkfçk", "sdjçlkj", "sadjfl",
            "sdfçls", "oirgk", "sdkfj"
        ])
    {
        assert(original_enc_dict[word] == H.encode_dictionary[word]);
    }

    assert(isAssociativeArray!(typeof(H.decode_dictionary)));
    foreach (key, val; H.decode_dictionary)
    {
        assert(isSomeString!(typeof(key)));
        assert(isArray!(typeof(val)));
        assert(key in original_dec_dict);
    }

}
