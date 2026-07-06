# Operation Runtime

The operation runtime is the controlled entrypoint for future operation requests.

PHASE86 creates the runtime skeleton only. It validates a request against an operation contract and prior smoke proof, then writes a dry-run execution plan. It does not execute the operation, install packages, create a virtual environment, create a production wrapper, or grant trust.

Operation contracts and smoke proofs are gates. A future executable runtime must honor the declared sandbox policy, allowed reads and writes, forbidden actions, and proof requirements before any controlled execution is allowed.

Materials cannot be called directly by external agents. Future use must pass through an operation contract, runtime request, sandbox policy, runtime report, and proof.
