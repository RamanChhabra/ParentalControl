package mdm

import (
	"bytes"
	"fmt"

	"howett.net/plist"
)

// DecodePlistDict decodes XML or binary plist into a string map (best-effort for MDM check-ins).
func DecodePlistDict(data []byte) (map[string]interface{}, error) {
	dec := plist.NewDecoder(bytes.NewReader(data))
	var raw interface{}
	if err := dec.Decode(&raw); err != nil {
		return nil, fmt.Errorf("plist decode: %w", err)
	}
	d, ok := raw.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("plist root is not a dict")
	}
	return d, nil
}

// EncodePlistXML encodes a map as XML plist bytes.
func EncodePlistXML(dict map[string]interface{}) ([]byte, error) {
	var buf bytes.Buffer
	enc := plist.NewEncoder(&buf)
	enc.Indent("\t")
	if err := enc.Encode(dict); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
