mean = (numbers...) ->
  sum = 0
  for number in numbers
    sum += number
  return sum/numbers.length

variance = (numbers...) ->
  mean_number = mean(numbers...)
  total_variance = 0
  for number in numbers
    total_variance += (mean_number - number) * (mean_number - number)
  return total_variance/numbers.length

window.undertone = ({
  context = new AudioContext()
  bit_length = 16
  gap_length = 16
  fft_size = 2048
  # TODO: parameterise the frequency gap, not the frequencies themselves
  clock_hz = 22050 # 1024/2048 * 44100
  signal_0_hz = 21878 # 1016/2048 * 44100
  signal_1_hz = 21705 # 1008/2048 * 44100
} = {}) ->

  clock_bin = Math.floor 0.5 + (fft_size * clock_hz)/44100
  signal_0_bin = Math.floor 0.5 + (fft_size * signal_0_hz)/44100
  signal_1_bin = Math.floor 0.5 + (fft_size * signal_1_hz)/44100

  console.log clock_bin, signal_0_bin, signal_1_bin

  return undertone = {

    broadcast: (message) ->

      duration = 1
      samples = Math.floor duration * context.sampleRate

      buffer = context.createBuffer(1, samples, context.sampleRate)
      channel_buffer = buffer.getChannelData(0)
      signal_hz = if Math.random() < 0.5 then signal_0_hz else signal_1_hz
      for a in [0...samples]
        channel_buffer[a] = (
          Math.cos(Math.PI * 2 * clock_hz * a/context.sampleRate) +
          Math.cos(Math.PI * 2 * signal_hz * a/context.sampleRate)
        )

      source = context.createBufferSource()
      source.buffer = buffer
      source.connect(context.destination)
      source.start()

    listen: (stream) -> new Promise (resolve, reject) ->

      # TODO: swap in my own FFT implementation, read the mic stream byte for byte

      analyser = context.createAnalyser()
      analyser.fftSize = fft_size

      source = context.createMediaStreamSource(stream)
      source.connect(analyser)

      frequency_buffer = new Float32Array(analyser.frequencyBinCount)
      setTimeout ->
        analyser.getFloatFrequencyData(frequency_buffer)

        signal_0 = frequency_buffer[signal_0_bin]
        signal_1 = frequency_buffer[signal_1_bin]
        clock = frequency_buffer[Math.min 1023, clock_bin]
        mid_clock_0 = frequency_buffer[Math.floor (clock_bin + signal_0_bin)/2]
        mid_0_1 = frequency_buffer[Math.floor (signal_0_bin + signal_1_bin)/2]

        console.log(
          signal_1
          mid_0_1
          signal_0
          mid_clock_0
          clock
        )

        # TODO: Make something more robust, this doesn't take into account that
        #       the signal should be louder than the background
        score_1 = variance(clock, signal_1) + variance(mid_0_1, signal_0, mid_clock_0)
        score_0 = variance(clock, signal_1, signal_0) + variance(mid_0_1, mid_clock_0)
        score_null = variance(clock, signal_1, signal_0, mid_0_1, mid_clock_0)

        console.log score_1, score_0, score_null
        min_score = Math.min(score_1, score_0, score_null)

        if min_score == score_1
          resolve(1)
        else if min_score == score_0
          resolve(0)
        else
          resolve(null)

      , 100
  }
