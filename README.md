# backwerds

Record yourself backwards. Play it forwards. 

ITS HILARIOUS

I love this little project as it provides a mountain of laughs. Also, good example of using some lower level core audio apis. 

Step One - Record and Save Audio Backwards
I recorded the audio via an `AudioOutputUnit` which takes the microphone buffer, reverses the bytes and converts it to a `CMSampleBufferRef`.  Then I pass this sample buffer to the viewcontroller who stores it an array. When recording is done, I empty this array FILO into a file writer. I now have the audio saved backwards.

Step Two - Looping Playback 
The playback of the reversed audio is done through a file reader that is responding to an `AudioOutputUnit` and its render callback. The gist of th looping mechanism is the `AudioOutputUnit` will continously tell its delegate the number of frames it wants to read and give a pointer to where it wants you to store them. The file reader keeps track of the number of frames the outout unit has read, seeks over to the audio file to the nexts frames it can read and saves them in the buffer.  If it is seeks passed the amount in the file, starts it over again. There is your loop.  

###PUT IT ALL TOGETHER
1. record something simple as a master track. 
2. Play master track backwards to memorize it.
3. Record the challenge track of yourself saying master backwards. 
4. Play challenge backwards.
     
Its a small app for the amount of laughs it has given me. 
