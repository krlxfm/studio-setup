CLICK_TO_BROADCAST : build cleanup

build :
	pyinstaller --onefile stream_studio.py
	cp dist/stream_studio CLICK_TO_BROADCAST

cleanup :
	rm -rf __pycache__ build dist stream_studio.spec

clean : cleanup
	rm -f CLICK_TO_BROADCAST
