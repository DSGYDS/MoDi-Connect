/*
 * SPDX-FileCopyrightText: 2026 Silvite
 * SPDX-License-Identifier: MS-PL
 */

/*++

Module Name:

    VirtualCable.h

Abstract:

    Shared ring buffer for render-to-capture audio data passthrough.
    Render stream writes PCM data, capture stream reads it.
    Thread-safe at DISPATCH_LEVEL (uses spinlock).

--*/

#ifndef _MODI_VIRTUAL_CABLE_H_
#define _MODI_VIRTUAL_CABLE_H_

// Ring buffer size: 96KB (~500ms at 48kHz/16bit/mono)
#define VIRTUAL_CABLE_BUFFER_SIZE   (96 * 1024)

class CVirtualCable
{
private:
    BYTE*       m_pBuffer;
    ULONG       m_ulBufferSize;
    ULONG       m_ulWritePos;
    ULONG       m_ulReadPos;
    ULONG       m_ulDataAvailable;    // bytes available for reading
    KSPIN_LOCK  m_SpinLock;
    BOOLEAN     m_bInitialized;

public:
    CVirtualCable() :
        m_pBuffer(NULL),
        m_ulBufferSize(VIRTUAL_CABLE_BUFFER_SIZE),
        m_ulWritePos(0),
        m_ulReadPos(0),
        m_ulDataAvailable(0),
        m_bInitialized(FALSE)
    {
        KeInitializeSpinLock(&m_SpinLock);
    }

    ~CVirtualCable()
    {
        if (m_pBuffer)
        {
            ExFreePoolWithTag(m_pBuffer, 'CVM');
            m_pBuffer = NULL;
        }
    }

    NTSTATUS Init()
    {
        if (m_bInitialized) return STATUS_SUCCESS;

        m_pBuffer = (BYTE*)ExAllocatePool2(
            POOL_FLAG_NON_PAGED,
            m_ulBufferSize,
            'CVM'  // MoDi Virtual Cable
        );

        if (!m_pBuffer) return STATUS_INSUFFICIENT_RESOURCES;

        RtlZeroMemory(m_pBuffer, m_ulBufferSize);
        m_ulWritePos = 0;
        m_ulReadPos = 0;
        m_ulDataAvailable = 0;
        m_bInitialized = TRUE;
        return STATUS_SUCCESS;
    }

    //
    // Called by render stream: write PCM data into the ring buffer.
    // If buffer is full, oldest data is overwritten (drop policy).
    //
    VOID Write(_In_reads_bytes_(Length) const BYTE* pData, _In_ ULONG Length)
    {
        if (!m_bInitialized || !pData || Length == 0) return;

        KIRQL oldIrql;
        KeAcquireSpinLock(&m_SpinLock, &oldIrql);

        // If incoming data is larger than buffer, only keep the tail
        if (Length >= m_ulBufferSize)
        {
            RtlCopyMemory(m_pBuffer, pData + (Length - m_ulBufferSize), m_ulBufferSize);
            m_ulWritePos = 0;
            m_ulReadPos = 0;
            m_ulDataAvailable = m_ulBufferSize;
            KeReleaseSpinLock(&m_SpinLock, oldIrql);
            return;
        }

        // Write data (may wrap around)
        ULONG firstChunk = min(Length, m_ulBufferSize - m_ulWritePos);
        RtlCopyMemory(m_pBuffer + m_ulWritePos, pData, firstChunk);
        if (Length > firstChunk)
        {
            RtlCopyMemory(m_pBuffer, pData + firstChunk, Length - firstChunk);
        }
        m_ulWritePos = (m_ulWritePos + Length) % m_ulBufferSize;

        // Update available data count
        m_ulDataAvailable += Length;
        if (m_ulDataAvailable > m_ulBufferSize)
        {
            // Overflow: advance read position (drop oldest)
            ULONG overflow = m_ulDataAvailable - m_ulBufferSize;
            m_ulReadPos = (m_ulReadPos + overflow) % m_ulBufferSize;
            m_ulDataAvailable = m_ulBufferSize;
        }

        KeReleaseSpinLock(&m_SpinLock, oldIrql);
    }

    //
    // Called by capture stream: read PCM data from the ring buffer.
    // If not enough data available, fills remainder with silence (zeros).
    //
    VOID Read(_Out_writes_bytes_(Length) BYTE* pData, _In_ ULONG Length)
    {
        if (!m_bInitialized || !pData || Length == 0) return;

        KIRQL oldIrql;
        KeAcquireSpinLock(&m_SpinLock, &oldIrql);

        if (m_ulDataAvailable == 0)
        {
            // No data: output silence
            RtlZeroMemory(pData, Length);
            KeReleaseSpinLock(&m_SpinLock, oldIrql);
            return;
        }

        ULONG toRead = min(Length, m_ulDataAvailable);

        // Read available data (may wrap around)
        ULONG firstChunk = min(toRead, m_ulBufferSize - m_ulReadPos);
        RtlCopyMemory(pData, m_pBuffer + m_ulReadPos, firstChunk);
        if (toRead > firstChunk)
        {
            RtlCopyMemory(pData + firstChunk, m_pBuffer, toRead - firstChunk);
        }
        m_ulReadPos = (m_ulReadPos + toRead) % m_ulBufferSize;
        m_ulDataAvailable -= toRead;

        // If we couldn't fill the entire request, pad with silence
        if (toRead < Length)
        {
            RtlZeroMemory(pData + toRead, Length - toRead);
        }

        KeReleaseSpinLock(&m_SpinLock, oldIrql);
    }

    // Reset buffer state (e.g., on stream stop)
    VOID Reset()
    {
        KIRQL oldIrql;
        KeAcquireSpinLock(&m_SpinLock, &oldIrql);
        m_ulWritePos = 0;
        m_ulReadPos = 0;
        m_ulDataAvailable = 0;
        if (m_pBuffer) RtlZeroMemory(m_pBuffer, m_ulBufferSize);
        KeReleaseSpinLock(&m_SpinLock, oldIrql);
    }
};

// Global singleton pointer (shared between render and capture streams)
// Avoids static C++ object initialization issues in kernel mode
extern CVirtualCable* g_pVirtualCable;

#endif // _MODI_VIRTUAL_CABLE_H_
