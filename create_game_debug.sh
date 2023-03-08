STORY=debug_story

rm -rf "./data/story/$STORY"

OPENAI_API_KEY=FAKE_OPENAI_KEY \
    DEBUG=true \
    bash -x generate_seed_assets.sh \
        "$STORY" \
        "there was once a bug. it was found in a switch deep inside the machine."
