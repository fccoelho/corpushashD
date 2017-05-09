import std.stdio;
import std.range;
import std.digest.sha;
import std.base64;
import std.path: buildPath, isValidFilename;
import std.format;
import std.uni;
import std.conv : to;
import std.random : randomSample;
import std.range : chain;
import std.typecons: tuple, Tuple;
import std.file;
import std.json;
import std.traits;

alias dictionary = dstring[string];
alias Ddictionary = dstring[2][string];
alias document = dstring[];


class HashCorpus
{
    document[] corpus;
    string corpus_path;
    string encoding;
    uint salt_length;
    dictionary encode_dictionary;
    Ddictionary decode_dictionary;
    string encode_dictionary_path;
    string decode_dictionary_path;
    string hash_function;

    this(document[] corpus,
        in string corpus_path,
        in string encoding="utf-32",
        in string hash_function="sha256",
        in uint salt_length=32)
    {
    this.corpus = corpus;
    this.corpus_path = corpus_path;
    this.encoding = encoding;
    this.hash_function = hash_function;
    this.salt_length = salt_length;
    this.encode_dictionary_path = buildPath(this.corpus_path, "private/encode_dictionary.pkl");
    this.decode_dictionary_path = buildPath(this.corpus_path, "private/decode_dictionary.pkl");
    auto dicts = this._load_dictionaries();
    this.encode_dictionary = dicts[0]; 
    this.decode_dictionary = dicts[1]; 
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
            this._export_encoded_document(encoded_document, encoded_document_path);
            ix += i;
        }
        this._export_dictionary(this.encode_dictionary, this.encode_dictionary_path);
        this._export_Ddictionary(this.decode_dictionary, this.decode_dictionary_path);
        writefln("%s documents hashed and saved to %s.", ix+1, buildPath(this.corpus_path, "public"));
    }

    dstring _encode_token(dstring token)
    {
        string hashed_token;
        dstring salt;

        if (to!string(token) in this.encode_dictionary)
        {
            return this.encode_dictionary[to!string(token)];
        }
        else
        {
            auto res = hash_token(token, hash_function=this.hash_function);
            hashed_token = res[0];
            salt = res[1];

            while (hashed_token in this.decode_dictionary)
            {
                res = hash_token(token, hash_function=this.hash_function);
                hashed_token = res[0];
                salt = res[1];
            }
            this.decode_dictionary[hashed_token] = [token, salt];
            this.encode_dictionary[to!string(token)] = to!dstring(hashed_token);
        }
        return to!dstring(hashed_token);
    }

    document _hash_document(document input_document, document output_document)
    {
        foreach (ix, item ;input_document)
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

    auto _load_dictionaries()
    {
        if (isValidFilename(this.encode_dictionary_path) && isValidFilename(this.decode_dictionary_path))
        {
        writeln("Dictionaries from previous hashing found.\n Loading them.");
        JSONValue encode_dictionary = this.encode_dictionary_path.readText.parseJSON;
        JSONValue decode_dictionary = this.decode_dictionary_path.readText.parseJSON;
        }
        else
        {
            dictionary encode_dictionary;
            Tuple!(dstring,dstring)[string] decode_dictionary;
            try{
                mkdir(buildPath(this.corpus_path, "private"));            
            }
            catch (FileException e){
                writeln(e);
            }            
            
        }
        return tuple(encode_dictionary, decode_dictionary);
    }
}

/**
* Hashes a string adding a random salt to it of specified size
* params:
*   token = string to be hashed
*   hash_function = Hash fuction to be used
*   salt = Salt to add
*   salt_length = Length of the salt in bits
*/
auto hash_token(dstring token, string hash_function, dstring salt=null, uint salt_length=32)
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
*/
dstring get_salt(uint siz)
{
    auto unicodechars = unicode("Cyrillic") | unicode("Armenian") | unicode("Telugu");
    dstring unichars =  to!(dstring)(unicodechars.byCodepoint);

    return to!dstring(randomSample(unichars, siz));
}

void main()
{
	writeln("Edit source/app.d to start your project.");
    writeln(get_salt(32));
}
