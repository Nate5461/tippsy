package auth

import "testing"

func TestHashAndCheckPassword(t *testing.T) {
	const plain = "correct horse battery staple"

	hash, err := HashPassword(plain)
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	if hash == plain {
		t.Fatal("hash must not equal the plaintext password")
	}

	if !CheckPassword(hash, plain) {
		t.Error("CheckPassword returned false for the correct password")
	}
	if CheckPassword(hash, "wrong password") {
		t.Error("CheckPassword returned true for an incorrect password")
	}
}
