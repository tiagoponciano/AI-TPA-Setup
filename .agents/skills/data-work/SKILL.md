---
name: data-work
description: Apply the project's conventions when working with notebooks, SQL, pipelines, ETL, or dbt.
---

<!-- GENERATED FILE — do not edit directly. Source: CLAUDE.md, skills/, rules/. Regenerate with scripts/generate-configs.sh -->

## Data work: pipelines, notebooks, analysis

Loaded when working with notebooks, SQL, or pipeline code.

"A test that fails without the change" rarely applies in its classic form here —
the logic lives in a query or a transformation, and the correctness question is
about data, not about a return value. The obligation still holds; the artifact
changes.

### The equivalent, in order of preference

1. **Golden output against a fixture.** Run the transformation on a small,
   committed sample and diff the result against a committed expected output. The
   closest analogue to a unit test, and the default for ETL steps.
2. **Schema assertion.** Column names, types, nullability and row-count bounds on
   the output — enforced in code (`pandera`, `great_expectations`, `dbt` tests, or
   a plain assert block), not checked by eye once.
3. **Invariant checks on the data.** The facts that must hold whatever the input:
   totals reconcile between stages, no duplicate keys after a join, no silent row
   loss, values inside their domain (a share is in `[0, 1]`, a TVL is not
   negative). One assertion per invariant, named after the invariant.
4. **Pure logic extracted and unit-tested.** Any calculation with a branch or a
   formula moves out of the notebook into a function, and that function gets a
   normal test. A notebook cell is not a place where logic hides from testing.

### Rules specific to this work

- **Fixtures are committed, production data never is.** If the sample can't be
  committed because of size or sensitivity, commit a generator or a redacted
  extract, and say so in the feature document.
- **A number that changed must be explained before it's accepted.** When a golden
  output diff shows a moved value, either the change caused it — say which
  change, in the PR — or it's a regression. Regenerating the golden file to make
  the diff go away is the failure mode this exists to prevent, and it is never
  done silently.
- **A notebook that only runs in the author's kernel is broken.** Clean-kernel
  top-to-bottom execution (`jupyter nbconvert --execute`) is the minimum bar and
  is the PR verification command for notebook work.
- **Never run a pipeline end-to-end on production data as verification.** Sample
  or fixture only.

### Units and scales

State the scale and unit of every numeric column in the feature document — `0-100`
vs `0-1`, `K USD` vs `USD`, the date format. Types don't carry that, and a wrong
scale passes every schema check silently.
