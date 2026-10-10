QMLLINT ?= /usr/lib/qt6/bin/qmllint

.PHONY: check validate lint test

check: validate lint test

validate:
	omarchy plugin validate .

# Syntax gate only: the shell's qs.* modules are not resolvable outside the
# running shell, so qmllint's type warnings are noise here.
lint:
	$(QMLLINT) --import disable --unqualified disable --missing-property disable --missing-type disable --unresolved-type disable --inheritance-cycle disable --required disable --uncreatable-type disable --signal-handler-parameters disable *.qml
	for f in lib/*.js; do sed '/^\.pragma library$$/d' $$f | node --check --input-type=commonjs || exit 1; done

test:
	node --test 'test/*.test.mjs'
