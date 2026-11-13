---
name: ste-writer
description: Write or rewrite technical English in a controlled, simplified style inspired by ASD-STE100 Simplified Technical English. Use for documentation, procedures, runbooks, error messages, release notes, and prompts when the user asks for STE, simplified technical English, or unambiguous instructions.
---

# Simplified technical English writer

Write clear, literal technical English that a non-native reader or a machine can parse without guessing. The style is inspired by ASD-STE100, not a certified implementation of it.

## Words

- Use one word for one meaning, and one meaning for one word. Keep the same term for the same thing in the whole text.
- Prefer short, common words: "use", not "utilize"; "start", not "initiate"; "help", not "facilitate".
- Use technical names exactly as they are in the source: product names, identifiers, commands, and UI labels.
- Do not use idioms, metaphors, slang, or phrasal verbs with an unclear meaning ("set up" is acceptable; "kick off" is not).
- Do not use a verb as a noun or a noun as a verb when a clear verb exists ("check the value", not "do a check of the value").

## Sentences

- Keep procedural sentences to 20 words or fewer and descriptive sentences to 25 words or fewer.
- Write one topic per sentence and one topic per paragraph. Keep paragraphs to six sentences or fewer.
- Use the active voice. Use the passive voice only when the agent is unknown or not important.
- Use simple tenses: simple present, simple past, and simple future.
- Include articles ("the", "a") and short connecting words. Do not write in telegraph style.
- Do not put more than three nouns in a row. Rewrite long noun clusters with prepositions.

## Procedures

- Write instructions in the imperative: "Open the file." Write one instruction per sentence, except for simultaneous actions.
- Put each step in a numbered list, in the order the reader does them.
- Put conditions first: "If the test fails, read the log."
- Write warnings and cautions before the step they apply to. Start with a clear command and then give the risk.

## Workflow

1. Identify the content type: procedure or description.
2. Rewrite the text with the rules above. Keep all facts, values, code, and formatting.
3. If a rule conflicts with technical accuracy, keep the accurate wording.
4. Return the rewritten text or edit the requested file. List violations or the changes you made only if the user asks for a review.

Do not use this style for marketing copy, fiction, or casual messages unless the user asks.
