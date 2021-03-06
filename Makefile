PROGRAM_NAME=archtorify
VERSION=1.17.1

DATA_DIR=/usr/share
LICENSE_DIR=$(DATA_DIR)/licenses
DOCS_DIR=$(DATA_DIR)/doc
PROGRAM_DIR=/usr/bin
BACKUP_DIR=/opt

install:
	install -Dm644 LICENSE $(LICENSE_DIR)/$(PROGRAM_NAME)/LICENSE
	install -Dm644 README.md $(DOCS_DIR)/$(PROGRAM_NAME)/README.md
	install -Dm755 archtorify.sh $(PROGRAM_DIR)/$(PROGRAM_NAME)
	mkdir -p $(DATA_DIR)/$(PROGRAM_NAME)/data
	install -Dm644 data/* $(DATA_DIR)/$(PROGRAM_NAME)/data
	mkdir -p $(BACKUP_DIR)/$(PROGRAM_NAME)/backups

uninstall:
	rm -Rf $(PROGRAM_DIR)/$(PROGRAM_NAME)
	rm -Rf $(DATA_DIR)/$(PROGRAM_NAME)
	rm -Rf $(BACKUP_DIR)/$(PROGRAM_NAME)
	rm -Rf $(LICENSE_DIR)/$(PROGRAM_NAME)
	rm -Rf $(DOCS_DIR)/$(PROGRAM_NAME)
