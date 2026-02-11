# Quick Start Guide: The "Recursive Architect" Workflow

This workflow adds a "Product Manager" hat to your stack of hats while Gemini and Claude handle the "Engineer" and "QA" roles of your "team".

> Wait, _GEMINI?_

Yeah, I use Gemini (`Fast`, `Thinking`, & `Pro`, depending on the situation) since it's free. And if I am unsure about something Claude does, it's like getting a second opinion.

I tend to use Gemini as the Architect, and Claude as the Builder. I also try to maintain rules for both of them to act as the Safety Inspector's guidelines.

Let's read through this workflow as though we are conversing with Gemini...

---

## Phase 1: The Blueprint (Gemini & User)

1. **Start with me (Gemini):** Tell me your idea. I will generate a `SPEC.md` that defines the features, tech stack, and core logic.
2. **Refine:** We'll iterate until the spec is solid.
3. **Deploy:** Copy the `SPEC.md` into your local project folder (which then gets synced into your Vault volume).

## Phase 2: The Battle Plan (Claude)

1. **Enter the Vault:** `docker exec -it [project_name]_container bash`.
2. **Hand over the Spec:** Tell Claude:

    > "Read `SPEC.md`. Create a `PLAN.md` that breaks this down into small, testable, atomic steps. For each step, identify what code needs to be written and what tests will prove it works."

3. **Review the Plan:** Make sure the steps aren't too big. Atomic steps prevent Claude from getting "lost" or hitting token limits mid-task.

## Phase 3: The Automation Loop (Claude Execution)

To get Claude to work recursively while you do other things, give it a "System Instruction" prompt like this:

> **"Your Goal:** Execute `PLAN.md` one step at a time.
> **For each step:**
>
> 1. Create a new branch: `git checkout -b step-x`.
> 2. Write the code and corresponding tests.
> 3. Run tests. If they fail, you have **3 attempts** to refactor and fix.
> 4. If you fail 3 times, write the error logs to `debug.log`, save your progress to `STATE.md`, and **stop**.
> 5. If tests pass:
>
> - Update `STATE.md` with what was accomplished.
> - Commit: `git add . && git commit -m 'feat: complete step x'`.
> - Move to the next step in a new branch.
>
> **Token Safety:** If you are nearing your context limit or token budget, save the current status to `STATE.md` and wait for my next input."

## Phase 4: Monitoring (The "Manager" View)

Because you're running in a named volume, you can watch the progress from outside:

- **Real-time files:** Open the container in VSCode via **Dev Containers** to see `STATE.md` or `debug.log` update as Claude works.
- **Logs:** Run `docker compose logs -f` to see the "heartbeat" of the Claude process.

## Phase "V": Verification

While Claude is great at writing tests, it can sometimes write "hallucinated" tests that pass even when they shouldn't.

- **The Fix:** Every 3-4 steps, jump into the container and intentionally break a piece of code to see if the tests actually catch it. This ensures Claude hasn't built a "house of cards."

### Logic Check & Step-by-Step Summary:

1. **Intent:** Remind user of socket security and provide a workflow for Gemini/Claude collaboration.
2. **Security Confirmation:** Verified `setup-project.sh` omits the Docker socket.
3. **Workflow Design:** Created a 4-phase plan (Blueprint, Plan, Execution Loop, Monitoring).
4. **Automation:** Provided a specific prompt for Claude to handle the "Recursive" tasks you requested.

**Ready to try this with your first POC idea? Just drop the idea here, and we'll start on the `SPEC.md`!**
