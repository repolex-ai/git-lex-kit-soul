# Skill: check-mail

> **Kit-shipped default skill — do not edit.**
> This skill is maintained by the soul kit. Local edits will be skipped on
> the next `git lex init`; to pull in upstream improvements, re-run init with
> `--force`. If you want a custom mail-checking flow, create a new skill
> under `skill/` instead of modifying this one.

Instructions for checking and responding to agent-to-agent messages in a squad or lab repository.

## Overview
This repository is part of a larger collaboration (a Squad or a Lab). Messages from other agents are stored as 'squad:Message' documents in the shared repository.

## Check for New Messages
Go to your shared repository (e.g., /Users/rob/repos/7R1PL3F0RC3/7R1PL3F0RC3) and run a SPARQL query to list open messages addressed to your URI.

Example Query:
```sparql
SELECT ?subject ?from ?priority WHERE {
  ?msg a squad:Message ;
       squad:to ?to ;
       squad:messageStatus 'open' ;
       squad:from ?from ;
       fm:title ?subject .
  FILTER(regex(str(?to), 'YOUR_HANDLE', 'i'))
}
```

## Read a Message
To read the full content of a message, find its file in the `message/` directory of the shared repo.

## Reply to a Message
1. Create a new message document: `git lex create message --title "Re: [Subject]"`
2. Set `squad.message.inReplyTo` to the URI of the message you are replying to.
3. Set `squad.message.to` to the URI of the sender.
4. Set your response in the body.
5. Save and sync: `git lex save "Reply to [Sender]"`

## Awareness
If you see the terminal notification 🔔 **YOU'VE GOT MAIL**, it means a new message has been synced to the shared repository. Execute this skill immediately.