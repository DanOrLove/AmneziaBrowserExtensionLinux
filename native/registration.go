package main

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

const nativeHostName = "com.amnezia.browser_vpn"

type extensionSigningKey struct {
	Key string `json:"key"`
}

type nativeHostManifest struct {
	Name           string   `json:"name"`
	Description    string   `json:"description"`
	Path           string   `json:"path"`
	Type           string   `json:"type"`
	AllowedOrigins []string `json:"allowed_origins"`
}

func registerNativeHost(uninstall bool) error {
	executable, err := os.Executable()
	if err != nil {
		return fmt.Errorf("cannot locate the native host: %w", err)
	}
	nativeDir := filepath.Dir(executable)
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot locate the current user's home directory: %w", err)
	}
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" || !filepath.IsAbs(configHome) {
		configHome = filepath.Join(home, ".config")
	}
	manifestName := nativeHostName + ".json"
	manifestPaths := make([]string, 0, 6)
	for _, browserPath := range []string{
		"google-chrome",
		"google-chrome-for-testing",
		"chromium",
		"microsoft-edge",
		filepath.Join("BraveSoftware", "Brave-Browser"),
		"vivaldi",
	} {
		manifestPaths = append(manifestPaths, filepath.Join(
			configHome, browserPath, "NativeMessagingHosts", manifestName,
		))
	}

	if uninstall {
		for _, path := range manifestPaths {
			if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
				return fmt.Errorf("cannot remove Native Messaging manifest %q: %w", path, err)
			}
		}
		fmt.Println("Native Messaging registration removed for Chrome, Chrome for Testing, Chromium, Edge, Brave, and Vivaldi.")
		return nil
	}

	keyBytes, err := os.ReadFile(filepath.Join(nativeDir, "..", "extension", "manifest.json"))
	if err != nil {
		return fmt.Errorf("cannot read extension/manifest.json: %w", err)
	}
	var extension extensionSigningKey
	if err := json.Unmarshal(keyBytes, &extension); err != nil {
		return fmt.Errorf("cannot parse extension/manifest.json: %w", err)
	}
	key, err := base64.StdEncoding.DecodeString(extension.Key)
	if err != nil || len(key) == 0 {
		return errors.New("extension/manifest.json must contain a valid base64 signing key")
	}
	checksum := sha256.Sum256(key)
	extensionID := make([]byte, 0, 32)
	for _, value := range checksum[:16] {
		extensionID = append(extensionID, 'a'+value>>4, 'a'+value&0x0f)
	}
	manifestBytes, err := json.Marshal(nativeHostManifest{
		Name:           nativeHostName,
		Description:    "Local AmneziaWG SOCKS5 tunnel for Chromium on Linux",
		Path:           executable,
		Type:           "stdio",
		AllowedOrigins: []string{"chrome-extension://" + string(extensionID) + "/"},
	})
	if err != nil {
		return fmt.Errorf("cannot create Native Messaging manifest: %w", err)
	}
	if err := os.Chmod(executable, 0700); err != nil {
		return fmt.Errorf("cannot make the native host executable: %w", err)
	}
	for _, path := range manifestPaths {
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return fmt.Errorf("cannot create Native Messaging directory %q: %w", filepath.Dir(path), err)
		}
		if err := os.WriteFile(path, manifestBytes, 0600); err != nil {
			return fmt.Errorf("cannot write Native Messaging manifest %q: %w", path, err)
		}
	}
	fmt.Println("Native Messaging host registered for Chrome, Chrome for Testing, Chromium, Edge, Brave, and Vivaldi (current Linux user).")
	fmt.Printf("Host path: %s\n", executable)
	return nil
}
