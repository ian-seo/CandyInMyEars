"""
CIME - Candy in My Ears

This is a python code for filtering bad words, which can be used for generating audio file as a training data
"""

__author__ = "Donghwan Seo"
__copyright__ = "Copyright 2021, CIME project"
__email__ = "dong88.seo@gmail.com"

from google.cloud import speech
import io
import os


path = './BadWords.m4a'
out_path = 'BadWords.wav'
filtered_out_path = 'BadWords_filtered.wav'

bad_words = [
    '시발',
    '씨발',
    '썅년',
    '썅놈',
    '개새',
    '쌍놈',
    '쌍년',
    '지랄',
    '병신',
    '18',
    '바보',
    '쉣',
    '멍청',
    '닥쳐',
    '꺼져',
    '미친'
  ]



def transcribe_file_with_word_time_offsets():
    """Transcribe the given audio file."""
    
    client = speech.SpeechClient()

    # Make two channels to one and convert aac to pcm wav
    # import ffmpeg
    # stream = ffmpeg.input(path).output(out_path, ac=1).overwrite_output().run()

    with io.open(out_path, "rb") as audio_file:
        content = audio_file.read()

    audio = speech.RecognitionAudio(content=content)
    config = speech.RecognitionConfig(
        sample_rate_hertz=44100,
        encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
        language_code="ko-KR",
        enable_word_time_offsets=True,
    )

    response = client.recognize(config=config, audio=audio)

    def check_bad_words(word):
        for string in bad_words:
            if string in word:
                return True
        return False

    # Each result is for a consecutive portion of the audio. Iterate through
    # them to get the transcripts for the entire audio file.
    for result in response.results:
        alternative = result.alternatives[0]
        print("Transcript: {}".format(alternative.transcript))
        print("Confidence: {}".format(alternative.confidence))

        mute_string = ''
        
        for word_info in alternative.words:
            word = word_info.word
            start_time = word_info.start_time
            end_time = word_info.end_time

            if check_bad_words(word):
                mute_string = mute_string + f'between(t,{start_time.total_seconds()},{end_time.total_seconds()})+'

            print(f"Word: {word}, start_time: {start_time.total_seconds()}, end_time: {end_time.total_seconds()}")

        if len(mute_string) > 0:
            mute_string = mute_string[:-1]
    
    os.system(f"ffmpeg -y -i {out_path} -af volume=volume=0.03:enable='{mute_string}' -c:v copy -c:a pcm_s16le -b:a 192K {filtered_out_path}")


if __name__ == "__main__":
    transcribe_file_with_word_time_offsets()